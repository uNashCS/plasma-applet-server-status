/***************************************************************************
 *   Copyright (C) 2017 by MakG <makg@makg.eu>                             *
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.notification

PlasmoidItem {
	id: root

	property int lastRefreshAt: 0
	property int statusSummary: 1
	property var diagnosticReports: ({})
	property var diagnosticRunning: ({})

	Layout.fillWidth: true
	Layout.fillHeight: true
	width: 250
	height: 300

// 	Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
	toolTipTextFormat: Text.RichText

	ServersModel {
		id: serversModel
	}

	Component {
		id: serverNotificationComponent

		Notification {
			id: serverNotification

			property string serverName: ""
			property string serverHostname: ""

			componentName: "org.kde.plasma.serverstatus"
			autoDelete: true
			flags: Notification.CloseOnTimeout | Notification.SkipGrouping
			hints: ({
				"desktop-entry": "org.kde.plasma.serverstatus",
				"x-kde-appname": "org.kde.plasma.serverstatus"
			})
			actions: [
				NotificationAction {
					label: i18n("Refresh")
					onActivated: root.action_refreshAll()
				},
				NotificationAction {
					label: i18n("Diagnose")
					onActivated: root.showDiagnostic({
						name: serverNotification.serverName,
						hostname: serverNotification.serverHostname
					})
				}
			]
		}
	}

	DiagnosticDialog {
		id: diagnosticDialog
	}

	Component {
		id: automaticDiagnosticComponent

		DiagnosticRunner {
			id: automaticRunner

			onFinished: root.finishDiagnostic(reportKey, automaticRunner)
			onFailed: function(message) {
				root.failDiagnostic(reportKey, message, automaticRunner);
			}
		}
	}

	Component.onCompleted: {
		migrateNotificationConfig();
		reloadServerModel();
	}

	Plasmoid.contextualActions: [
		PlasmaCore.Action {
			text: i18n("Refresh all")
			icon.name: "view-refresh"
			onTriggered: action_refreshAll()
		}
	]

	Connections {
		target: Plasmoid.configuration

		onServersChanged: {
			reloadServerModel();
		}
	}

	compactRepresentation: Item {
		Kirigami.Icon {
			anchors.fill: parent
			source: statusSummary == 1 ? Plasmoid.configuration.iconOnline : Plasmoid.configuration.iconOffline
		}


		MouseArea {
			id: mouseArea
			anchors.fill: parent

			onClicked: {
				root.expanded = !root.expanded
			}
		}
	}

	fullRepresentation: Item {
		Layout.preferredWidth: 300
		Layout.preferredHeight: 300

		ListView {
			id: serversListView
			anchors.fill: parent
			model: serversModel
			delegate: Row {
				height: nameText.paintedHeight * 1.5

				Kirigami.Icon {
					id: icon

					width: parent.height
					height: parent.height
					source: model.status == 1 ? Plasmoid.configuration.iconOnline : Plasmoid.configuration.iconOffline
					opacity: model.refreshing ? 0.2 : 1.0
				}

				PlasmaComponents.BusyIndicator {
					width: parent.height
					height: parent.height
					anchors.horizontalCenter: icon.horizontalCenter
					running: model.refreshing
					visible: model.refreshing
				}
// 				PlasmaComponents.Label {
// 					id: timeText
//
// 					anchors.left: icon.right
// 					anchors.leftMargin: 10
//
// 					text: time
// 					height: parent.height
// 					verticalAlignment: Text.AlignVCenter
// 					font.pointSize: 12
// 				}
				PlasmaComponents.Label {
					id: nameText

					anchors.left: icon.right
					anchors.leftMargin: 10

					height: parent.height
					text: model.name.length == 0 ? model.hostname : model.name
					verticalAlignment: Text.AlignVCenter
					font.pointSize: Plasmoid.configuration.fontSize
				}

				QQC2.Menu {
					id: serverMenu

					QQC2.MenuItem {
						text: i18n("Refresh")
						icon.name: "view-refresh"
						onTriggered: refreshServer(model.index)
					}

					QQC2.MenuItem {
						text: i18n("Diagnose route...")
						icon.name: "network-connect"
						onTriggered: showDiagnostic(model)
					}

					QQC2.MenuItem {
						text: i18n("View last diagnostic")
						icon.name: "document-open"
						enabled: hasDiagnostic(model.hostname)
						onTriggered: showLastDiagnostic(model)
					}
				}

				MouseArea {
					id: mouseArea

					anchors.top: icon.top
					anchors.right: nameText.right
					anchors.bottom: icon.bottom
					anchors.left: icon.left
					hoverEnabled: true
					acceptedButtons: Qt.LeftButton | Qt.RightButton
					onClicked: function(mouse) {
						if(mouse.button === Qt.RightButton) {
							serverMenu.popup();
						} else {
							refreshServer(model.index);
						}
					}
				}
			}
		}

		PlasmaComponents.Button {
			anchors.centerIn: parent
			text: i18n("Configure...")
			visible: serversModel.count == 0
			onClicked: Plasmoid.internalAction("configure").trigger();
		}
	}

	Timer {
		id: serversTimer
		interval: 1 * 1000
		running: false
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			lastRefreshAt = new Date().getTime() / 1000;

			for(var i = 0; i < serversModel.count; i++) {
				if(!serversModel.get(i).refreshing && lastRefreshAt - serversModel.get(i).lastRefreshAt >= serversModel.get(i).refreshRate) {
					refreshServer(i);
				}
			}
		}
	}

	Plasma5Support.DataSource {
		id: executableDS
		engine: "executable"
		connectedSources: []
		property variant cmdMap: ({})

		onNewData: {
			var index = cmdMap[sourceName];

			try {
				parseResponse(index, data["exit code"], data.stdout);
			} catch(e) {
				console.log("Error processing server response:", e);

				if(index !== undefined) {
					serversModel.setProperty(index, "refreshing", false);
				}
			}

			exited(sourceName, data.stdout);
			disconnectSource(sourceName);
		}

		function exec(cmd, serverIndex) {
				cmdMap[cmd] = serverIndex

				connectSource(cmd)
		}
		signal exited(string sourceName, string stdout)
	}

	Plasma5Support.DataSource {
		id: notifyExecDS
		engine: "executable"
		connectedSources: []

		onNewData: {
				exited(sourceName, data.stdout)
				disconnectSource(sourceName)
		}

		function exec(cmd) {
				connectSource(cmd)
		}
		signal exited(string sourceName, string stdout)
	}

	function reloadServerModel() {
		serversModel.clear();

		try {
			var servers = JSON.parse(Plasmoid.configuration.servers || '[]');

			for(var i = 0; i < servers.length; i++) {
				if(servers[i].active) {
					servers[i].refreshing = false;
					servers[i].lastRefreshAt = 0;
					servers[i].status = 0;

					serversModel.append(servers[i]);
				}
			}
		} catch (e) {
			console.log("Error parsing servers configuration:", e);
		}

		serversTimer.restart();
	}

	function refreshServer(index) {
		serversModel.setProperty(index, "refreshing", true);

		var command = '';

		switch(serversModel.get(index).method) {
			case 1: // PINGV6
				command = 'ping6 -c 1 ' + serversModel.get(index).hostname;
				break;

			case 2: // HTTP 200 OK
				command = 'curl -sL -w "%{http_code}" "' + serversModel.get(index).hostname + '" -o /dev/null';
				break;

			case 3: // COMMAND
				command = serversModel.get(index).extraOptions.command.replace(/\%hostname\%/g, serversModel.get(index).hostname);
				break;

			case 0: // PING
			default:
				command = 'ping -c 3 ' + serversModel.get(index).hostname;
				break;
		}

		executableDS.exec(command, index);
	}

	function parseResponse(index, exitCode, stdout) {
		var status = 0;

		switch(serversModel.get(index).method) {
			case 1: // PINGV6
				status = exitCode == 0 ? 1 : 0;
				break;

			case 2: // HTTP 200 OK
				status = stdout.indexOf("200") !== -1 ? 1 : 0;
				break;

			case 3: // COMMAND
				status = exitCode == 0 ? 1 : 0;
				break;

			case 0: // PING
			default:
				status = exitCode == 0 ? 1 : 0;
				break;
		}

		var server = serversModel.get(index);
		var wasKnown = server.known === true;
		var statusChanged = wasKnown && server.status != status;
		var shouldDiagnose = statusChanged && status === 0;

		serversModel.setProperty(index, "status", status);
		serversModel.setProperty(index, "known", true);
		serversModel.setProperty(index, "refreshing", false);
		serversModel.setProperty(index, "lastRefreshAt", new Date().getTime() / 1000);

		updateStatusSummary();

		if(statusChanged) {
			try {
				notify(index, status);
			} catch(e) {
				console.log("Notification failed:", e);
			}
		}

		if(shouldDiagnose) {
			try {
				startAutomaticDiagnostic(server);
			} catch(e) {
				console.log("Automatic diagnostic failed to start:", e);
			}
		}
	}

	function updateStatusSummary() {
		var status = 1;

		for(var i = 0; i < serversModel.count; i++) {
			if(serversModel.get(i).status != 1) {
				status = 0;
				break;
			}
		}

		statusSummary = status;
	}

	function showDiagnostic(server) {
		if(!server || !server.hostname) {
			return;
		}

		diagnosticDialog.showFor(server.name, server.hostname);
	}

	function hasDiagnostic(hostname) {
		var key = String(hostname || "");
		return key.length > 0 && diagnosticReports[key] !== undefined;
	}

	function showLastDiagnostic(server) {
		if(!server) {
			return;
		}

		var key = String(server.hostname || "");
		var report = diagnosticReports[key];

		if(report === undefined) {
			return;
		}

		diagnosticDialog.showReport(server.name, server.hostname, report);
	}

	function startAutomaticDiagnostic(server) {
		if(!Plasmoid.configuration.diagnosticAutoOffline || !server) {
			return;
		}

		var key = String(server.hostname || "");

		if(key.length === 0 || diagnosticRunning[key] === true) {
			return;
		}

		setDiagnosticRunning(key, true);

		var runner = automaticDiagnosticComponent.createObject(root, { reportKey: key });

		if(!runner) {
			setDiagnosticRunning(key, false);
			return;
		}

		try {
			runner.start(server.hostname, server.name, key);
		} catch(e) {
			console.log("Automatic diagnostic failed:", e);
			failDiagnostic(key, String(e), runner);
		}
	}

	function finishDiagnostic(key, runner) {
		setDiagnosticReport(key, {
			output: runner.output,
			error: runner.error,
			note: runner.note,
			tool: runner.tool,
			exitCode: runner.exitCode,
			timestamp: new Date().getTime()
		});
		setDiagnosticRunning(key, false);
		Qt.callLater(function() { runner.destroy(); });
	}

	function failDiagnostic(key, message, runner) {
		setDiagnosticReport(key, {
			output: "",
			error: message,
			note: "",
			tool: runner ? runner.tool : "",
			exitCode: -1,
			timestamp: new Date().getTime()
		});
		setDiagnosticRunning(key, false);

		if(runner) {
			Qt.callLater(function() { runner.destroy(); });
		}
	}

	function setDiagnosticReport(key, report) {
		var reports = {};

		for(var existingKey in diagnosticReports) {
			reports[existingKey] = diagnosticReports[existingKey];
		}

		reports[String(key)] = report;
		diagnosticReports = reports;
	}

	function setDiagnosticRunning(key, value) {
		var running = {};

		for(var existingKey in diagnosticRunning) {
			running[existingKey] = diagnosticRunning[existingKey];
		}

		if(value) {
			running[String(key)] = true;
		} else {
			delete running[String(key)];
		}

		diagnosticRunning = running;
	}

	function notify(serverIndex, status) {
		if(serverIndex < 0 || serverIndex >= serversModel.count) {
			return;
		}

		var server = serversModel.get(serverIndex);
		var action = status === 0 ? Plasmoid.configuration.notificationDownAction : Plasmoid.configuration.notificationUpAction;
		var commandTemplate = status === 0 ? Plasmoid.configuration.notificationDownCommand : Plasmoid.configuration.notificationUpCommand;

		switch(Number(action)) {
			case 1: // System notification
				sendSystemNotification(server, status);
				break;

			case 2: // Command
				if(commandTemplate && commandTemplate.length > 0) {
					notifyExecDS.exec(expandCommand(commandTemplate, server));
				}
				break;

			case 0: // Nothing
			default:
				break;
		}
	}

	function sendSystemNotification(server, status) {
		var offline = status === 0;
		var serverName = server.name && server.name.length > 0 ? server.name : server.hostname;
		var notification = serverNotificationComponent.createObject(root, {
			eventId: offline ? "serverOffline" : "serverOnline",
			title: offline ? i18n("Server offline") : i18n("Server online"),
			text: offline
				? i18n("%1 (%2) is not responding.", serverName, server.hostname)
				: i18n("%1 (%2) is responding again.", serverName, server.hostname),
			iconName: offline ? "dialog-error" : "dialog-information",
			urgency: offline ? Notification.CriticalUrgency : Notification.NormalUrgency,
			serverName: serverName,
			serverHostname: server.hostname
		});

		if(notification) {
			notification.sendEvent();
		}
	}

	function expandCommand(template, server) {
		return String(template || "")
			.replace(/%hostname%/g, server.hostname)
			.replace(/%name%/g, server.name || server.hostname);
	}

	function migrateNotificationConfig() {
		var config = Plasmoid.configuration;

		if(config.notificationConfigMigrated) {
			return;
		}

		try {
			var legacyUp = JSON.parse(config.notificationUp || '{}');
			var legacyDown = JSON.parse(config.notificationDown || '{}');

			if(legacyUp && typeof legacyUp.action === "number") {
				config.notificationUpAction = legacyUp.action;
				config.notificationUpCommand = (legacyUp.extraOptions && legacyUp.extraOptions.command) || "";
			}

			if(legacyDown && typeof legacyDown.action === "number") {
				config.notificationDownAction = legacyDown.action;
				config.notificationDownCommand = (legacyDown.extraOptions && legacyDown.extraOptions.command) || "";
			}
		} catch (e) {
			console.log("Error migrating legacy notification configuration:", e);
		}

		config.notificationConfigMigrated = true;
	}

	function action_refreshAll() {
		for(var i = 0; i < serversModel.count; i++) {
			refreshServer(i);
		}
	}
}
