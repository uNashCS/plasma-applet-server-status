import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Plasma5Support.DataSource {
	id: runner

	property string hostname: ""
	property string serverName: ""
	property string reportKey: ""
	property bool running: false
	property bool usingFallback: false
	property string tool: ""
	property string output: ""
	property string error: ""
	property string note: ""
	property int exitCode: -1
	property string activeSource: ""

	signal finished()
	signal failed(string message)

	engine: "executable"
	connectedSources: []

	onNewData: function(sourceName, data) {
		handleResult(sourceName, data);
	}

	Component.onDestruction: cancel()

	function start(host, name, key) {
		cancel();

		hostname = "";
		serverName = String(name || "").trim();
		reportKey = key !== undefined && key !== null ? String(key) : String(host || "").trim();
		running = false;
		usingFallback = false;
		tool = "";
		output = "";
		error = "";
		note = "";
		exitCode = -1;

		var normalized = normalizeHost(host);

		if(normalized.length === 0) {
			fail(i18n("The server host name is empty."));
			return;
		}

		if(!isSafeHost(normalized)) {
			fail(i18n("The server host name contains unsupported characters."));
			return;
		}

		hostname = normalized;
		running = true;
		tool = "mtr";
		runMtr();
	}

	function cancel() {
		if(activeSource.length > 0) {
			disconnectSource(activeSource);
			activeSource = "";
		}

		running = false;
	}

	function normalizeHost(value) {
		var host = String(value || "").trim();

		if(host.length === 0) {
			return "";
		}

		host = host.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "");
		host = host.replace(/^[^@/]*@/, "");
		host = host.replace(/\/.*$/, "");

		if(host.charAt(0) === "[") {
			var closingBracket = host.indexOf("]");
			if(closingBracket > 0) {
				return host.substring(1, closingBracket);
			}
		}

		if((host.match(/:/g) || []).length === 1) {
			host = host.replace(/:\d+$/, "");
		}

		return host;
	}

	function isSafeHost(host) {
		return host.length > 0
			&& host.charAt(0) !== "-"
			&& /^[A-Za-z0-9._:%-]+$/.test(host);
	}

	function shellQuote(value) {
		return "'" + String(value).replace(/'/g, "'\\''") + "'";
	}

	function runMtr() {
		activeSource = "timeout 30s mtr -rwc 3 -b " + shellQuote(hostname);
		connectSource(activeSource);
	}

	function runTracepath() {
		tool = "tracepath";
		activeSource = "timeout 20s tracepath -b " + shellQuote(hostname);
		connectSource(activeSource);
	}

	function handleResult(sourceName, data) {
		var stdout = data.stdout || "";
		var stderr = data.stderr || "";
		var code = Number(data["exit code"]);

		disconnectSource(sourceName);
		activeSource = "";

		if(tool === "mtr" && shouldFallback(code, stdout, stderr)) {
			usingFallback = true;
			note = i18n("mtr was not available or failed; using tracepath.");
			runTracepath();
			return;
		}

		running = false;
		exitCode = code;
		output = stdout;
		error = stderr.trim();

		if(code === 124) {
			error = i18n("The diagnostic timed out.");
		} else if(code !== 0 && error.length === 0 && output.trim().length === 0) {
			error = i18n("The diagnostic command failed with exit code %1.", code);
		}

		finished();
	}

	function shouldFallback(code, stdout, stderr) {
		if(code === 0) {
			return false;
		}

		var message = String(stderr || "").toLowerCase();

		return code === 124
			|| code === 126
			|| code === 127
			|| message.indexOf("not found") !== -1
			|| message.indexOf("no such file") !== -1
			|| message.indexOf("permission denied") !== -1
			|| message.indexOf("operation not permitted") !== -1
			|| message.indexOf("socket") !== -1;
	}

	function fail(message) {
		running = false;
		exitCode = -1;
		output = "";
		error = message;
		failed(message);
	}
}
