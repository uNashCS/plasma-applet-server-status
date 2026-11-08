import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
	id: configNotifications

	property alias cfg_notificationUpAction: notifyUpAction.currentIndex
	property alias cfg_notificationUpCommand: notifyUpCommand.text
	property alias cfg_notificationDownAction: notifyDownAction.currentIndex
	property alias cfg_notificationDownCommand: notifyDownCommand.text

	Plasma5Support.DataSource {
		id: testNotificationDS
		engine: "executable"
		connectedSources: []

		onNewData: function(sourceName, data) {
			disconnectSource(sourceName);
		}

		function exec(cmd) {
			connectSource(cmd);
		}
	}

	Kirigami.FormLayout {
		QQC2.Label {
			Kirigami.FormData.isSection: true
			text: i18n("When a server goes online")
		}

		QQC2.ComboBox {
			id: notifyUpAction
			Kirigami.FormData.label: i18n("Action:")
			model: [i18n("Nothing"), i18n("System notification"), i18n("Command")]
			Layout.fillWidth: true
		}

		QQC2.TextField {
			id: notifyUpCommand
			Kirigami.FormData.label: i18n("Command:")
			Layout.fillWidth: true
			visible: notifyUpAction.currentIndex === 2
			placeholderText: i18n("Enter command...")
		}

		QQC2.Label {
			Layout.fillWidth: true
			wrapMode: Text.WordWrap
			visible: notifyUpAction.currentIndex === 2
			font.pointSize: Kirigami.Theme.smallFont.pointSize
			text: i18n("Commands run with /bin/sh -c. Use %hostname% and %name% as placeholders.")
		}

		QQC2.Label {
			Kirigami.FormData.isSection: true
			text: i18n("When a server goes offline")
		}

		QQC2.ComboBox {
			id: notifyDownAction
			Kirigami.FormData.label: i18n("Action:")
			model: [i18n("Nothing"), i18n("System notification"), i18n("Command")]
			Layout.fillWidth: true
		}

		QQC2.TextField {
			id: notifyDownCommand
			Kirigami.FormData.label: i18n("Command:")
			Layout.fillWidth: true
			visible: notifyDownAction.currentIndex === 2
			placeholderText: i18n("Enter command...")
		}

		QQC2.Label {
			Layout.fillWidth: true
			wrapMode: Text.WordWrap
			visible: notifyDownAction.currentIndex === 2
			font.pointSize: Kirigami.Theme.smallFont.pointSize
			text: i18n("Commands run with /bin/sh -c. Use %hostname% and %name% as placeholders.")
		}

		QQC2.Button {
			Kirigami.FormData.label: i18n("Test:")
			text: i18n("Send test notification")
			icon.name: "notifications"
			onClicked: {
				testNotificationDS.exec("notify-send --app-name=" + shellQuote("Server Status")
					+ " --urgency=critical --icon=" + shellQuote("dialog-error")
					+ " " + shellQuote(i18n("Server Status"))
					+ " " + shellQuote(i18n("This is a test notification. If you can read this, notifications work.")));
			}
		}
	}

	function shellQuote(value) {
		return "'" + String(value).replace(/'/g, "'\\''") + "'";
	}
}
