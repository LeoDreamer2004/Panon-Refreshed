import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18ndc("plasma_applet_panon", "@title", "Appearance")
        icon: "applications-multimedia"
        source: "config/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18ndc("plasma_applet_panon", "@title", "Backend")
        icon: "preferences-system"
        source: "config/ConfigServices.qml"
    }
    ConfigCategory {
        name: i18ndc("plasma_applet_panon", "@title", "Music integrations")
        icon: "applications-multimedia"
        source: "config/ConfigIntegrations.qml"
    }
}
