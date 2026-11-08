import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notification

KCM.SimpleKCM {
	id: configNotifications

	property alias cfg_notificationUpAction: notifyUpAction.currentIndex
	property alias cfg_notificationUpCommand: notifyUpCommand.text
	property alias cfg_notificationDownAction: notifyDownAction.currentIndex
	property alias cfg_notificationDownCommand: notifyDownCommand.text

	Plasma5Support.DataSource {
		id: settingsDS
		engine: "executable"
		connectedSources: []

		onNewData: function(sourceName, data) {
			disconnectSource(sourceName);
		}

		function exec(cmd) {
			connectSource(cmd);
		}
	}

	Component {
		id: testNotificationComponent

		Notification {
			componentName: "org.kde.plasma.serverstatus"
			autoDelete: true
			flags: Notification.CloseOnTimeout | Notification.SkipGrouping
			hints: ({
				"desktop-entry": "org.kde.plasma.serverstatus",
				"x-kde-appname": "org.kde.plasma.serverstatus"
			})
		}
	}

	Kirigami.FormLayout {
		QQC2.Label {
			Layout.fillWidth: true
			wrapMode: Text.WordWrap
			font.pointSize: Kirigami.Theme.smallFont.pointSize
			text: i18n("Notification sounds and popups are configured in System Settings → Notifications → Server Status.")
		}

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
			text: i18n("Offline notification")
			icon.name: "dialog-error"
			onClicked: sendTestNotification("serverOffline", i18n("Server offline"), "dialog-error", Notification.CriticalUrgency)
		}

		QQC2.Button {
			text: i18n("Online notification")
			icon.name: "dialog-information"
			onClicked: sendTestNotification("serverOnline", i18n("Server online"), "dialog-information", Notification.NormalUrgency)
		}

		QQC2.Button {
			text: i18n("Configure notification sounds...")
			icon.name: "preferences-desktop-notification"
			onClicked: settingsDS.exec("kcmshell6 kcm_notifications")
		}
	}

	function sendTestNotification(eventId, title, iconName, urgency) {
		var notification = testNotificationComponent.createObject(configNotifications, {
			eventId: eventId,
			title: title,
			text: i18n("This is a test notification. If you can read this, notifications work."),
			iconName: iconName,
			urgency: urgency
		});

		if(notification) {
			notification.sendEvent();
		}
	}
}
