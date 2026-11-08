import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

QQC2.ApplicationWindow {
	id: diagnosticDialog

	property string serverName: ""
	property string hostname: ""
	property string output: ""
	property string error: ""
	property string note: ""
	property string tool: ""
	property int exitCode: -1
	property bool cancelled: false
	property int cycles: 3

	readonly property int maxWidth: Screen.width > 0 ? Math.round(Screen.width * 0.85) : Kirigami.Units.gridUnit * 70
	readonly property int maxHeight: Screen.height > 0 ? Math.round(Screen.height * 0.8) : Kirigami.Units.gridUnit * 40

	title: serverName.length > 0 ? i18n("Network diagnostic: %1", serverName) : i18n("Network diagnostic")
	flags: Qt.Dialog
	modality: Qt.NonModal
	visible: false

	width: Math.min(Kirigami.Units.gridUnit * 60, maxWidth)
	height: Math.min(Kirigami.Units.gridUnit * 40, maxHeight)
	minimumWidth: Math.min(Kirigami.Units.gridUnit * 30, maxWidth)
	minimumHeight: Math.min(Kirigami.Units.gridUnit * 20, maxHeight)

	onClosing: function(close) {
		if(runner.running) {
			runner.cancel();
			cancelled = true;
		}

		close.accepted = true;
	}

	DiagnosticRunner {
		id: runner

		onFinished: {
			diagnosticDialog.output = runner.output;
			diagnosticDialog.error = runner.error;
			diagnosticDialog.note = runner.note;
			diagnosticDialog.tool = runner.tool;
			diagnosticDialog.exitCode = runner.exitCode;
			diagnosticDialog.cancelled = false;
		}
		onFailed: function(message) {
			diagnosticDialog.error = message;
			diagnosticDialog.cancelled = false;
		}
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: Kirigami.Units.largeSpacing
		spacing: Kirigami.Units.smallSpacing

		RowLayout {
			Layout.fillWidth: true

			PlasmaComponents.BusyIndicator {
				Layout.preferredWidth: Kirigami.Units.iconSizes.small
				Layout.preferredHeight: Kirigami.Units.iconSizes.small
				running: runner.running
				visible: runner.running
			}

			QQC2.Label {
				Layout.fillWidth: true
				wrapMode: Text.WordWrap
				text: runner.running
					? (runner.tool === "tracepath" ? i18n("Running tracepath...") : i18n("Running mtr..."))
					: (diagnosticDialog.cancelled
						? i18n("Diagnostic cancelled")
						: (diagnosticDialog.error.length > 0 && diagnosticDialog.output.length === 0
							? i18n("Diagnostic failed")
							: i18n("Diagnostic finished")))
			}
		}

		QQC2.Label {
			Layout.fillWidth: true
			wrapMode: Text.WordWrap
			visible: diagnosticDialog.note.length > 0
			font.italic: true
			font.pointSize: Kirigami.Theme.smallFont.pointSize
			text: diagnosticDialog.note
		}

		QQC2.ScrollView {
			Layout.fillWidth: true
			Layout.fillHeight: true
			visible: runner.running || diagnosticDialog.output.length > 0
			clip: true

			QQC2.TextArea {
				id: outputArea
				text: diagnosticDialog.output
				readOnly: true
				selectByMouse: true
				wrapMode: TextEdit.NoWrap
				font.family: "monospace"
				font.pointSize: Kirigami.Theme.smallFont.pointSize
				placeholderText: runner.running ? i18n("Waiting for results...") : ""
			}
		}

		QQC2.Label {
			Layout.fillWidth: true
			wrapMode: Text.WordWrap
			visible: diagnosticDialog.error.length > 0
			color: Kirigami.Theme.negativeTextColor
			text: diagnosticDialog.error
		}

		RowLayout {
			Layout.fillWidth: true

			QQC2.Label {
				text: i18n("Cycles:")
			}

			QQC2.SpinBox {
				id: cyclesSpinBox

				from: 1
				to: 30
				value: diagnosticDialog.cycles
				enabled: !runner.running
				onValueChanged: diagnosticDialog.cycles = value
			}

			Item {
				Layout.fillWidth: true
			}

			QQC2.Button {
				text: i18n("Copy")
				icon.name: "edit-copy"
				enabled: diagnosticDialog.output.length > 0

				onClicked: {
					outputArea.selectAll();
					outputArea.copy();
				}
			}

			QQC2.Button {
				text: i18n("Run again")
				icon.name: "view-refresh"
				enabled: !runner.running && diagnosticDialog.hostname.length > 0

				onClicked: runDiagnostic()
			}

			QQC2.Button {
				text: i18n("Close")
				icon.name: "window-close"

				onClicked: diagnosticDialog.close()
			}
		}
	}

	function centerOnScreen() {
		if(visible) {
			return;
		}

		var s = screen;

		if(s) {
			x = Math.max(0, Math.round((s.width - width) / 2));
			y = Math.max(0, Math.round((s.height - height) / 2));
		}
	}

	function showFor(name, host, cyclesValue) {
		serverName = String(name || "").trim();
		hostname = String(host || "").trim();
		cycles = Math.min(30, Math.max(1, Number(cyclesValue) || 3));
		output = "";
		error = "";
		note = "";
		tool = "";
		exitCode = -1;
		cancelled = false;

		centerOnScreen();
		show();
		Qt.callLater(runDiagnostic);
	}

	function showReport(name, host, report) {
		serverName = String(name || "").trim();
		hostname = String(host || "").trim();
		runner.cancel();
		cancelled = false;

		output = report && report.output ? report.output : "";
		error = report && report.error ? report.error : "";
		note = report && report.note ? report.note : "";
		tool = report && report.tool ? report.tool : "";
		exitCode = report && report.exitCode !== undefined ? report.exitCode : -1;

		centerOnScreen();
		show();
	}

	function runDiagnostic() {
		if(hostname.length === 0) {
			error = i18n("The server host name is empty.");
			return;
		}

		output = "";
		error = "";
		note = "";
		tool = "";
		exitCode = -1;
		cancelled = false;

		runner.start(hostname, serverName, hostname, cycles);
	}
}
