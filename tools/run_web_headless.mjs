#!/usr/bin/env node
/**
 * Headless-прогон проекта официальным Web-шаблоном Godot 4.7.2 под Node.js.
 *
 * Нужен там, где нет нативного редактора/сборки Godot: движок Web-платформы
 * запускается как обычный Emscripten-модуль, а PCK подкладывается в его
 * виртуальную файловую систему — так же, как это делает официальный Web-экспорт.
 *
 * Примеры:
 *   node tools/run_web_headless.mjs web/index.pck --quit-after 240
 *   node tools/run_web_headless.mjs /tmp/tests.pck --script res://tests/test_runner.gd
 *
 * Файлы движка берутся из web/ (или из путей в GODOT_WEB_JS / GODOT_WEB_WASM).
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const [pckArg, ...engineArgs] = process.argv.slice(2);
if (!pckArg) {
	console.error('Использование: node tools/run_web_headless.mjs <project.pck> [аргументы движка]');
	process.exit(2);
}

const pckPath = path.resolve(pckArg);
const pckName = path.basename(pckPath);
const here = path.dirname(new URL(import.meta.url).pathname);
const jsPath = process.env.GODOT_WEB_JS || path.join(here, '..', 'web', 'godot.web.template_release.wasm32.nothreads.js');
const wasmPath = process.env.GODOT_WEB_WASM || path.join(here, '..', 'web', 'godot.web.template_release.wasm32.nothreads.wasm');

const { default: Godot } = await import(path.resolve(jsPath));

const module = await Godot({
	wasmBinary: fs.readFileSync(wasmPath),
	locateFile: (file) => path.join(path.dirname(path.resolve(jsPath)), file),
	print: (text) => process.stdout.write(`${text}\n`),
	printErr: (text) => process.stderr.write(`${text}\n`),
});

// Заглушка канваса: движок идёт в headless, но его JS-обвязка при выходе
// обращается к canvas.style — без объекта это падает уже после теста.
const canvasStub = {
	id: 'canvas',
	style: {},
	focus() {},
	blur() {},
	addEventListener() {},
	removeEventListener() {},
	setAttribute() {},
	getAttribute: () => null,
	getBoundingClientRect: () => ({ left: 0, top: 0, width: 640, height: 275 }),
	clientWidth: 640,
	clientHeight: 275,
};

await module.initFS([]);
module.initConfig({
	canvas: canvasStub,
	canvasResizePolicy: 2,
	locale: 'ru',
	virtualKeyboard: false,
	persistentDrops: false,
	godotPoolSize: 4,
});

const pack = fs.readFileSync(pckPath);
module.copyToFS(pckName, pack);

// Минимальное браузерное окружение: движок идёт в headless, canvas и звук не нужны,
// но часть проверок JS-обвязки обращается к window/document.
globalThis.window = { devicePixelRatio: 1, addEventListener() {}, removeEventListener() {}, alert() {} };
globalThis.document = {
	createElement: () => ({ style: {}, addEventListener() {}, removeEventListener() {} }),
	addEventListener() {},
	removeEventListener() {},
	getElementById: () => canvasStub,
	body: {},
};

const args = engineArgs.length > 0 ? [...engineArgs] : ['--quit-after', '240'];
if (!args.includes('--headless')) {
	args.unshift('--headless');
}
if (!args.includes('--main-pack')) {
	args.unshift('--main-pack', pckName);
}

// Web-движок намеренно не завершает процесс сам (в браузере это недопустимо),
// поэтому забираем код выхода себе. Кадры и сценарии выполняются асинхронно,
// так что выходить сразу после callMain нельзя — ждём, пока опустеет event loop.
let exitStatus = 0;
let engineExited = false;
const engineCleanup = module.onExit;
module.onExit = (status) => {
	engineExited = true;
	exitStatus = typeof status === 'number' ? status : 0;
	if (typeof engineCleanup === 'function') {
		try {
			engineCleanup(status);
		} catch (error) {
			// уборка ресурсов движка в headless не критична
		}
	}
};

try {
	module.callMain(args);
} catch (error) {
	// godot.quit(code) выбрасывает ExitStatus — это штатное завершение прогона.
	if (typeof error?.status === 'number') {
		exitStatus = error.status;
		engineExited = true;
	} else {
		throw error;
	}
}

// Обвязка браузерной сборки доделывает уборку в микротасках и иногда падает
// на этом этапе — после штатного выхода движка это не должно влиять на код возврата.
process.on('uncaughtException', (error) => {
	if (!engineExited) {
		throw error;
	}
});
process.on('unhandledRejection', (reason) => {
	if (!engineExited) {
		throw reason;
	}
});

process.on('beforeExit', () => {
	process.exitCode = exitStatus;
});
