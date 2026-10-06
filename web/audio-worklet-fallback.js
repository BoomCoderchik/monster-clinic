/**
 * Заглушка AudioWorklet для страниц без secure context (обычный HTTP).
 *
 * `AudioWorklet` — API только для secure context: по HTTPS и на localhost он
 * доступен, а по обычному HTTP свойства `audioWorklet` у `AudioContext` просто
 * нет. Godot 4.7 инициализирует звук в `GodotAudio.init()`, который безусловно
 * вызывает `ctx.audioWorklet.addModule("godot.audio.position.worklet.js")`,
 * поэтому на HTTP движок падал с «Cannot read properties of undefined
 * (reading 'addModule')» ещё до первого кадра — вместо кабинета был чёрный
 * экран.
 *
 * Здесь мы подменяем отсутствующий API минимальной заглушкой: движок выбирает
 * свою worklet-ветку и стартует, а звуковые эффекты игры работают, потому что
 * сэмплы (AudioStreamPlayer с AudioStreamWAV) идут по графу WebAudio прямо в
 * `AudioContext.destination`, минуя worklet-микшер. Не работают только
 * микрофонный вход и точная позиция воспроизведения — в этой игре не нужны.
 *
 * Модуль импортируется первым в `index.js` и обязан выполниться раньше
 * `godot.web.template_release.*.js`: движок забирает конструктор
 * `AudioWorkletNode` на этапе вычисления своего модуля.
 */

const NOOP = () => {};

/**
 * Узел-заглушка. Отдаём настоящий AudioNode (GainNode), иначе браузер не даст
 * подключить его к графу: `source.connect(plainObject)` бросает TypeError.
 * Поверх него — port и parameters, которых ждёт движок от AudioWorkletNode.
 * Выход заглушки никуда не подключён, поэтому она ничего не микширует: звук
 * игры идёт мимо неё.
 */
class FallbackAudioWorkletNode {
	constructor(context, name) {
		const node = context.createGain();
		node.name = name;
		node.parameters = new Map([
			['reset', { value: 0, setValueAtTime: NOOP, linearRampToValueAtTime: NOOP }],
		]);
		node.port = {
			onmessage: null,
			onmessageerror: null,
			postMessage: NOOP,
			start: NOOP,
			close: NOOP,
		};
		return node;
	}
}

/**
 * Проверка без обращения к геттеру: у `audioWorklet` на прототипе нельзя
 * спросить значение (`proto.audioWorklet` в secure context бросает
 * «Illegal invocation»), а `in` не вызывает геттер. В обычном HTTP браузер
 * вообще не создаёт это свойство, поэтому проверка видит его отсутствие.
 */
function audioWorkletAvailable() {
	const context = window.AudioContext || window.webkitAudioContext;
	if (!context || !window.isSecureContext) {
		return false;
	}
	return 'audioWorklet' in context.prototype;
}

function installAudioWorkletFallback() {
	const proto = (window.BaseAudioContext || window.AudioContext || {}).prototype;
	if (!proto || audioWorkletAvailable()) {
		return false;
	}
	try {
		Object.defineProperty(proto, 'audioWorklet', {
			configurable: true,
			get: () => ({ addModule: () => Promise.resolve() }),
		});
	} catch (error) {
		console.warn('Не удалось включить заглушку AudioWorklet:', error);
		return false;
	}
	// Сам конструктор в браузере есть, но без глобального скоупа воркл не
	// создаётся («AudioWorklet does not have a valid AudioWorkletGlobalScope»),
	// поэтому подменяем его целиком.
	window.AudioWorkletNode = FallbackAudioWorkletNode;
	console.info('Аудио в упрощённом режиме: AudioWorklet требует HTTPS или localhost — эффекты идут напрямую через WebAudio.');
	return true;
}

export const audioWorkletFallbackActive = installAudioWorkletFallback();
