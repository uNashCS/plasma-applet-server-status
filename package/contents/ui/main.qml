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
	property var latencyHistory: ({})

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
			delegate: Item {
				id: serverRow

				width: ListView.view.width
				height: nameText.implicitHeight * 1.6

				property string tooltipText: {
					var lines = [];
					lines.push(model.name.length == 0 ? model.hostname : model.name);
					lines.push(i18n("Host: %1", model.hostname));
					lines.push(i18n("Method: %1", methodLabel(model.method)));
					lines.push(i18n("Last check: %1", formatAge(model.lastRefreshAt)));

					if(model.detail && model.detail.length > 0) {
						lines.push(i18n("Result: %1", model.detail));
					}

					if(hasDiagnostic(model.hostname)) {
						lines.push(i18n("Diagnostic available"));
					}

					lines.push(i18n("Left click: refresh · Right click: options"));
					return lines.join("\n");
				}

				QQC2.ToolTip {
					id: rowToolTip

					parent: serverRow

					property bool cursorInside: false

					visible: mouseArea.containsMouse || rowToolTip.cursorInside
					delay: 400
					closePolicy: QQC2.Popup.CloseOnEscape
					x: Math.round((serverRow.width - width) / 2)
					y: {
						var rowY = serverRow.mapToItem(serversListView, 0, 0).y;

						if(rowY >= height + Kirigami.Units.smallSpacing * 2) {
							return -height - Kirigami.Units.smallSpacing;
						}

						return serverRow.height + Kirigami.Units.smallSpacing;
					}

					contentItem: ColumnLayout {
						spacing: Kirigami.Units.smallSpacing
						width: 240

						HoverHandler {
							onHoveredChanged: rowToolTip.cursorInside = hovered
						}

						QQC2.Label {
							Layout.fillWidth: true
							wrapMode: Text.WordWrap
							text: serverRow.tooltipText
						}

						QQC2.Label {
							Layout.fillWidth: true
							visible: hasLatencyData(model.hostname)
							font.pointSize: Kirigami.Theme.smallFont.pointSize
							wrapMode: Text.NoWrap
							elide: Text.ElideRight
							text: latencyStats(model.hostname)
						}

						LatencySparkline {
							Layout.preferredWidth: 240
							Layout.preferredHeight: 40
							visible: hasLatencyData(model.hostname)
							samples: root.latencyHistory[model.hostname] || []
							windowSeconds: Math.max(60, Number(Plasmoid.configuration.latencyHistoryMinutes) * 60)
						}

						QQC2.Label {
							Layout.fillWidth: true
							visible: hasLatencyMethod(model.method) && !hasLatencyData(model.hostname)
							font.pointSize: Kirigami.Theme.smallFont.pointSize
							color: Kirigami.Theme.disabledTextColor
							text: i18n("Collecting latency data…")
						}
					}
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: Kirigami.Units.smallSpacing
					anchors.rightMargin: Kirigami.Units.smallSpacing
					spacing: Kirigami.Units.smallSpacing

					Item {
						id: iconContainer

						Layout.preferredWidth: nameText.implicitHeight * 1.2
						Layout.preferredHeight: nameText.implicitHeight * 1.2
						Layout.alignment: Qt.AlignVCenter

						Kirigami.Icon {
							id: icon

							anchors.fill: parent
							source: model.status == 1 ? Plasmoid.configuration.iconOnline : Plasmoid.configuration.iconOffline
							opacity: model.refreshing ? 0.2 : 1.0
						}

						PlasmaComponents.BusyIndicator {
							anchors.centerIn: parent
							width: parent.width
							height: parent.height
							running: model.refreshing
							visible: model.refreshing
						}
					}

					PlasmaComponents.Label {
						id: nameText

						Layout.fillWidth: true
						text: model.name.length == 0 ? model.hostname : model.name
						elide: Text.ElideRight
						verticalAlignment: Text.AlignVCenter
						font.pointSize: Plasmoid.configuration.fontSize
					}

					PlasmaComponents.Label {
						id: detailText

						Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
						text: model.detail || ""
						visible: text.length > 0
						color: levelColor(model.detailLevel)
						font.pointSize: Math.max(1, Plasmoid.configuration.fontSize - 2)
					}
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

					anchors.fill: parent
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
					servers[i].detail = "";
					servers[i].detailLevel = 0;

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
				command = 'ping6 -c 1 -W 2 -w 4 ' + serversModel.get(index).hostname;
				break;

			case 2: // HTTP 200 OK
				command = 'curl -sL --connect-timeout 4 --max-time 8 -w "%{http_code} %{time_total}" "' + serversModel.get(index).hostname + '" -o /dev/null';
				break;

			case 3: // COMMAND
				command = serversModel.get(index).extraOptions.command.replace(/\%hostname\%/g, serversModel.get(index).hostname);
				break;

			case 0: // PING
			default:
				command = 'ping -c 3 -W 2 -w 8 ' + serversModel.get(index).hostname;
				break;
		}

		executableDS.exec(command, index);
	}

	function parseResponse(index, exitCode, stdout) {
		var method = serversModel.get(index).method;
		var status = 0;

		switch(method) {
			case 1: // PINGV6
				status = exitCode == 0 ? 1 : 0;
				break;

			case 2: // HTTP 200 OK
				var httpParts = String(stdout || "").trim().split(/\s+/);
				status = parseInt(httpParts[0], 10) === 200 ? 1 : 0;
				break;

			case 3: // COMMAND
				status = exitCode == 0 ? 1 : 0;
				break;

			case 0: // PING
			default:
				status = exitCode == 0 ? 1 : 0;
				break;
		}

		var detailInfo = computeDetail(method, status, stdout);

		var server = serversModel.get(index);
		var wasKnown = server.known === true;
		var statusChanged = wasKnown && server.status != status;
		var shouldDiagnose = statusChanged && status === 0;

		serversModel.setProperty(index, "status", status);
		serversModel.setProperty(index, "known", true);
		serversModel.setProperty(index, "refreshing", false);
		serversModel.setProperty(index, "lastRefreshAt", new Date().getTime() / 1000);
		serversModel.setProperty(index, "detail", detailInfo.text);
		serversModel.setProperty(index, "detailLevel", detailInfo.level);

		recordLatency(server.hostname, detailInfo.latency, status === 1);

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

	function computeDetail(method, status, stdout) {
		var text = "";
		var level = 0;
		var latency = -1;

		if(method === 2) {
			var parts = String(stdout || "").trim().split(/\s+/);
			var code = parseInt(parts[0], 10);
			var timeSeconds = parseFloat(parts[1]);

			if(isNaN(code)) {
				code = -1;
			}

			if(code >= 0) {
				text = String(code);
				level = code === 200 ? 1 : (code >= 200 && code < 400 ? 2 : 3);
			} else {
				text = i18n("Fail");
				level = 3;
			}

			if(!isNaN(timeSeconds) && timeSeconds > 0) {
				latency = timeSeconds * 1000;
			}
		} else if(method === 0 || method === 1) {
			var match = String(stdout || "").match(/=\s*([\d.,]+)\/([\d.,]+)\/([\d.,]+)\/([\d.,]+)\s*ms/);

			if(match) {
				var avg = parseFloat(match[2].replace(",", "."));
				text = avg.toFixed(1) + " ms";
				level = avg < 150 ? 1 : (avg < 400 ? 2 : 3);
				latency = avg;
			} else {
				text = status === 1 ? "OK" : i18n("Fail");
				level = status === 1 ? 1 : 3;
			}
		} else {
			text = status === 1 ? "OK" : i18n("Fail");
			level = status === 1 ? 1 : 3;
		}

		return { text: text, level: level, latency: latency };
	}

	function recordLatency(host, latencyMs, ok) {
		if(latencyMs < 0) {
			return;
		}

		var key = String(host || "");

		if(key.length === 0) {
			return;
		}

		var now = Math.floor(Date.now() / 1000);
		var minutes = Number(Plasmoid.configuration.latencyHistoryMinutes) || 60;
		var cutoff = now - minutes * 60;

		var arr = latencyHistory[key] ? latencyHistory[key].slice() : [];
		arr.push({ t: now, v: latencyMs, ok: ok === true });

		var filtered = [];

		for(var i = 0; i < arr.length; i++) {
			if(arr[i].t >= cutoff) {
				filtered.push(arr[i]);
			}
		}

		if(filtered.length > 720) {
			filtered = filtered.slice(filtered.length - 720);
		}

		var next = {};

		for(var existingKey in latencyHistory) {
			next[existingKey] = latencyHistory[existingKey];
		}

		next[key] = filtered;
		latencyHistory = next;
	}

	function hasLatencyMethod(method) {
		var m = Number(method);
		return m === 0 || m === 1 || m === 2;
	}

	function hasLatencyData(host) {
		var arr = latencyHistory[String(host || "")] || [];
		var count = 0;

		for(var i = 0; i < arr.length; i++) {
			if(arr[i].ok) {
				count++;
			}
		}

		return count >= 2;
	}

	function latencyStats(host) {
		var arr = latencyHistory[String(host || "")] || [];
		var min = -1;
		var max = -1;
		var sum = 0;
		var count = 0;

		for(var i = 0; i < arr.length; i++) {
			var s = arr[i];

			if(!s.ok || s.v < 0) {
				continue;
			}

			if(min < 0 || s.v < min) {
				min = s.v;
			}

			if(s.v > max) {
				max = s.v;
			}

			sum += s.v;
			count++;
		}

		if(count === 0) {
			return "";
		}

		return i18n("min %1 ms · avg %2 ms · max %3 ms", min.toFixed(0), (sum / count).toFixed(0), max.toFixed(0));
	}

	function levelColor(level) {
		switch(Number(level)) {
			case 1: return Kirigami.Theme.positiveTextColor;
			case 3: return Kirigami.Theme.negativeTextColor;
			case 2: return Kirigami.Theme.neutralTextColor;
			default: return Kirigami.Theme.disabledTextColor;
		}
	}

	function methodLabel(method) {
		switch(Number(method)) {
			case 1: return i18n("Ping (IPv6)");
			case 2: return i18n("HTTP");
			case 3: return i18n("Command");
			default: return i18n("Ping");
		}
	}

	function formatAge(timestamp) {
		if(!timestamp || timestamp <= 0) {
			return i18n("never");
		}

		var seconds = Math.max(0, Math.round(new Date().getTime() / 1000 - timestamp));

		if(seconds < 60) {
			return i18n("%1 seconds ago", seconds);
		}

		if(seconds < 3600) {
			return i18n("%1 minutes ago", Math.floor(seconds / 60));
		}

		return i18n("%1 hours ago", Math.floor(seconds / 3600));
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

		diagnosticDialog.showFor(server.name, server.hostname, Plasmoid.configuration.diagnosticCycles);
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
			runner.start(server.hostname, server.name, key, Plasmoid.configuration.diagnosticCycles);
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
