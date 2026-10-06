#!/usr/bin/env node
/**
 * Статический HTTP-сервер для папки web/ без зависимостей и без Python.
 *
 * Зачем: Web-сборка — это набор файлов, которые браузер обязан получить по HTTP
 * (`file://` не отдаёт .wasm и .pck). В репозитории для этого есть
 * `run-web-preview.sh` (Python), но на Windows Python часто не установлен —
 * тогда достаточно Node.js и этой команды:
 *
 *   node tools/serve_web.mjs            # порт 8080, открыть http://localhost:8080/
 *   node tools/serve_web.mjs 9000 --open
 *
 * Ключи:
 *   <порт>            порт (по умолчанию 8080)
 *   --open            открыть браузер после старта
 *   --root <папка>    что раздавать (по умолчанию web/)
 *   --bind <адрес>    адрес прослушивания (по умолчанию 0.0.0.0 — доступно и с телефона)
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
	const index = args.indexOf(name);
	return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
};
const port = Number(args.find((a) => /^\d+$/.test(a)) || 8080);
const bind = flag('--bind', '0.0.0.0');
const openBrowser = args.includes('--open');
const defaultRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)), 'web');
const root = path.resolve(flag('--root', defaultRoot));

const MIME = {
	'.html': 'text/html; charset=utf-8',
	'.js': 'text/javascript; charset=utf-8',
	'.mjs': 'text/javascript; charset=utf-8',
	'.css': 'text/css; charset=utf-8',
	'.json': 'application/json; charset=utf-8',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.jpg': 'image/jpeg',
	'.svg': 'image/svg+xml',
	'.ttf': 'font/ttf',
	'.ico': 'image/x-icon',
};

if (!fs.existsSync(path.join(root, 'index.html'))) {
	console.error(`Не нашёл ${path.join(root, 'index.html')}.`);
	console.error('Запускайте команду из корня проекта или укажите папку: node tools/serve_web.mjs --root web');
	process.exit(2);
}

const server = http.createServer((request, response) => {
	const urlPath = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
	const relative = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
	const file = path.resolve(root, relative);

	if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
		response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
		response.end(`404: ${relative}\n\nОткройте http://localhost:${port}/ — игра начинается с index.html.`);
		return;
	}

	const stats = fs.statSync(file);
	response.writeHead(200, {
		'content-type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
		'content-length': stats.size,
		'cache-control': 'no-cache',
	});
	if (request.method === 'HEAD') {
		response.end();
		return;
	}
	fs.createReadStream(file).pipe(response);
});

server.on('error', (error) => {
	if (error.code === 'EADDRINUSE') {
		console.error(`Порт ${port} уже занят — закройте другой сервер или укажите другой порт: node tools/serve_web.mjs ${port + 1}`);
		process.exit(1);
	}
	throw error;
});

server.listen(port, bind, () => {
	const url = `http://localhost:${port}/`;
	console.log(`Клиника монстров №13 → ${url}`);
	console.log(`Раздаётся: ${root}`);
	if (bind === '0.0.0.0') {
		console.log('Для других устройств в сети: http://<ip-этого-компьютера>:' + port + '/ (там будет упрощённый звук).');
	}
	console.log('Полный звук работает только на localhost или по HTTPS. Остановить сервер: Ctrl+C.');
	if (openBrowser) {
		const command = process.platform === 'win32' ? 'cmd' : process.platform === 'darwin' ? 'open' : 'xdg-open';
		const browserArgs = process.platform === 'win32' ? ['/c', 'start', '', url] : [url];
		// Обработчик ошибки обязателен: если открывалки нет в системе, событие
		// 'error' без слушателя роняет процесс — сервер умер бы вместе с ней.
		spawn(command, browserArgs, { stdio: 'ignore', detached: true })
			.on('error', (error) => {
				console.warn(`Не удалось открыть браузер автоматически (${error.message}). Откройте вручную: ${url}`);
			})
			.unref();
	}
});
