/**
 * Загрузчик Web-сборки «Клиники монстров №13».
 *
 * Повторяет порядок запуска официального Web-экспорта Godot 4:
 *   initFS → initConfig → copyToFS(PCK) → callMain(["--main-pack", ...]).
 *
 * Файлы рядом: index.html (шелл), index.pck (данные проекта),
 * godot.web.template_release.wasm32.nothreads.{js,wasm} — движок 4.7.2
 * (официальный шаблон Web, single-threaded), godot.audio.*.worklet.js — звук.
 *
 * Первым импортируется audio-worklet-fallback.js: на страницах без secure
 * context он подменяет недоступный AudioWorklet и не даёт движку упасть.
 */
import { audioWorkletFallbackActive } from './audio-worklet-fallback.js';
import Godot from './godot.web.template_release.wasm32.nothreads.js';

const WASM_FILE = 'godot.web.template_release.wasm32.nothreads.wasm';
const MAIN_PACK = 'index.pck';
const VIEW_W = 640;
const VIEW_H = 275;

const canvas = document.getElementById('canvas');
const status = document.getElementById('status');
const statusFill = document.getElementById('status-fill');
const statusNote = document.getElementById('status-note');
const audioHint = document.getElementById('audio-hint');

function showAudioHint() {
	if (!audioHint) {
		return;
	}
	audioHint.classList.add('visible');
	setTimeout(() => audioHint.classList.remove('visible'), 15000);
}

let progress = 0;

function setProgress(value, note) {
	progress = Math.max(progress, Math.min(1, value));
	statusFill.style.width = `${Math.round(progress * 100)}%`;
	if (note) {
		statusNote.textContent = note;
	}
}

function fail(error) {
	console.error(error);
	status.classList.remove('hidden');
	statusNote.classList.add('error');
	statusNote.textContent = `Не удалось запустить игру: ${error.message || error}. ` +
		'Проверьте, что страница открыта по HTTP(S) (а не как файл), рядом лежат index.pck и godot.web.template_release.wasm32.nothreads.wasm, ' +
		'а для полноценного звука адрес — HTTPS или localhost.';
}

async function fetchWithProgress(url, onProgress) {
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`${response.status} ${response.statusText} — ${url}`);
	}
	const total = Number(response.headers.get('content-length')) || 0;
	if (!response.body || !total) {
		const buffer = new Uint8Array(await response.arrayBuffer());
		onProgress(1);
		return buffer;
	}
	const reader = response.body.getReader();
	const chunks = [];
	let loaded = 0;
	for (;;) {
		const { done, value } = await reader.read();
		if (done) {
			break;
		}
		chunks.push(value);
		loaded += value.length;
		onProgress(loaded / total);
	}
	const result = new Uint8Array(loaded);
	let offset = 0;
	for (const chunk of chunks) {
		result.set(chunk, offset);
		offset += chunk.length;
	}
	return result;
}

async function start() {
	// Канвас под пропорции проекта: 640×275 с пиксельным апскейлом.
	canvas.width = VIEW_W;
	canvas.height = VIEW_H;

	setProgress(0, 'Грузим движок…');
	const wasmBinary = await fetchWithProgress(WASM_FILE, (ratio) => setProgress(ratio * 0.85, 'Грузим движок…'));

	const module = await Godot({
		wasmBinary,
		locateFile: (file) => new URL(file, import.meta.url).href,
		print: (text) => console.log(text),
		printErr: (text) => console.warn(text),
	});

	await module.initFS([]);
	module.initConfig({
		canvas,
		canvasResizePolicy: 2,
		locale: navigator.language || 'ru',
		virtualKeyboard: false,
		persistentDrops: false,
		godotPoolSize: 4,
		onExit: () => {},
	});

	setProgress(0.86, 'Раскладываем инструменты…');
	const pack = await fetchWithProgress(MAIN_PACK, (ratio) => setProgress(0.86 + ratio * 0.14, 'Раскладываем инструменты…'));
	module.copyToFS(MAIN_PACK, pack);

	module.callMain(['--main-pack', MAIN_PACK]);
	setProgress(1);
	canvas.focus();
	status.classList.add('hidden');
	setTimeout(() => status.remove(), 500);
	if (audioWorkletFallbackActive) {
		showAudioHint();
	}
}

start().catch(fail);
