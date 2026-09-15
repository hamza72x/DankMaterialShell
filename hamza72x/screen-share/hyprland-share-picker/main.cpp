#include <QApplication>
#include <QCheckBox>
#include <QCoreApplication>
#include <QEvent>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QHBoxLayout>
#include <QLabel>
#include <QObject>
#include <QPushButton>
#include <QScreen>
#include <QScrollArea>
#include <QSpacerItem>
#include <QStyle>
#include <QTabWidget>
#include <QVBoxLayout>
#include <QWidget>
#include <QtWidgets>
#include <array>
#include <cstdio>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
#include <hyprutils/os/Process.hpp>
using namespace Hyprutils::OS;

#include "mainpicker.h"
#include "selectioncard.h"

std::string execAndGet(const char* cmd) {
    CProcess proc("/bin/sh", {"-c", cmd});

    if (!proc.runSync())
        return "error";

    return proc.stdOut();
}

QApplication* pickerPtr     = nullptr;
MainPicker*   mainPickerPtr = nullptr;

struct SWindowEntry {
    std::string        name;
    std::string        clazz;
    unsigned long long id = 0;
};

std::vector<SWindowEntry> getWindows(const char* env) {
    std::vector<SWindowEntry> result;

    if (!env)
        return result;

    std::string rolling = env;

    while (!rolling.empty()) {
        const auto IDSEPPOS    = rolling.find("[HC>]");
        const auto IDSTR       = rolling.substr(0, IDSEPPOS);
        const auto CLASSSEPPOS = rolling.find("[HT>]");
        const auto CLASSSTR    = rolling.substr(IDSEPPOS + 5, CLASSSEPPOS - IDSEPPOS - 5);
        const auto TITLESEPPOS = rolling.find("[HE>]");
        const auto TITLESTR    = rolling.substr(CLASSSEPPOS + 5, TITLESEPPOS - 5 - CLASSSEPPOS);
        const auto WINDOWSEPPOS = rolling.find("[HA>]");

        try {
            result.push_back({TITLESTR, CLASSSTR, std::stoull(IDSTR)});
        } catch (std::exception& e) {
            // silent err
        }

        rolling = rolling.substr(WINDOWSEPPOS + 5);
    }

    return result;
}

static QString pickUiFont() {
    const QStringList candidates = {
        QStringLiteral("IBM Plex Sans"),
        QStringLiteral("Inter"),
        QStringLiteral("Source Sans 3"),
        QStringLiteral("Noto Sans"),
        QStringLiteral("Cantarell"),
        QStringLiteral("Sans Serif"),
    };
    const QStringList available = QFontDatabase::families();
    for (const auto& family : candidates) {
        if (available.contains(family))
            return family;
    }
    return QFont().family();
}

static QString pickerStyleSheet(const QString& fontFamily) {
    // Cool slate panel + seafoam accent — permission dialog, not a dashboard.
    return QStringLiteral(R"(
* {
    font-family: "%1";
}

QMainWindow, QWidget#centralwidget {
    background-color: #12161c;
    color: #e8eef6;
}

QLabel#heroTitle {
    color: #f4f7fb;
    font-size: 20px;
    font-weight: 600;
    letter-spacing: -0.3px;
}

QLabel#heroSubtitle {
    color: #8b98a8;
    font-size: 12.5px;
    font-weight: 400;
}

QTabWidget::pane {
    border: 1px solid #243041;
    border-radius: 12px;
    background: #171c24;
    top: -1px;
    padding: 8px;
}

QTabWidget::tab-bar {
    alignment: left;
}

QTabBar {
    qproperty-drawBase: 0;
}

QTabBar::tab {
    background: transparent;
    color: #8b98a8;
    padding: 10px 16px;
    margin-right: 4px;
    border: 1px solid transparent;
    border-radius: 9px;
    font-size: 12.5px;
    font-weight: 500;
    min-width: 72px;
}

QTabBar::tab:hover {
    color: #d7e0ea;
    background: #1c2430;
}

QTabBar::tab:selected {
    color: #041016;
    background: #5eead4;
    font-weight: 600;
}

QScrollArea {
    background: transparent;
    border: none;
}

QScrollArea > QWidget > QWidget {
    background: transparent;
}

QScrollBar:vertical {
    background: transparent;
    width: 8px;
    margin: 4px 2px 4px 0;
}

QScrollBar::handle:vertical {
    background: #2c384a;
    border-radius: 4px;
    min-height: 24px;
}

QScrollBar::handle:vertical:hover {
    background: #3d4d63;
}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
    height: 0;
    background: none;
}

QFrame#selectionCard {
    background: #1a222d;
    border: 1px solid #2a3648;
    border-radius: 12px;
}

QFrame#selectionCard[hovered="true"], QFrame#selectionCard:focus {
    background: #202a38;
    border: 1px solid #5eead4;
}

QLabel#cardTitle {
    color: #eef3f8;
    font-size: 13.5px;
    font-weight: 600;
}

QLabel#cardSubtitle {
    color: #8b98a8;
    font-size: 11.5px;
    font-weight: 400;
}

QLabel#cardChevron {
    color: #5eead4;
    font-size: 22px;
    font-weight: 400;
    min-width: 18px;
}

QCheckBox {
    color: #a9b6c5;
    font-size: 12px;
    spacing: 10px;
    padding: 6px 2px;
}

QCheckBox::indicator {
    width: 18px;
    height: 18px;
    border-radius: 5px;
    border: 1px solid #3a4a5e;
    background: #171c24;
}

QCheckBox::indicator:hover {
    border-color: #5eead4;
}

QCheckBox::indicator:checked {
    background: #5eead4;
    border-color: #5eead4;
    image: none;
}

QWidget#regionHint {
    background: #1a222d;
    border: 1px solid #2a3648;
    border-radius: 12px;
}
)").arg(fontFamily);
}

static void emitScreenSelection(QCheckBox* allowToken, const QString& outputName) {
    std::cout << "[SELECTION]";
    std::cout << (allowToken->isChecked() ? "r" : "");
    std::cout << "/";
    std::cout << "screen:" << outputName.toStdString() << "\n";
    pickerPtr->quit();
}

static void emitWindowSelection(QCheckBox* allowToken, unsigned long long id) {
    std::cout << "[SELECTION]";
    std::cout << (allowToken->isChecked() ? "r" : "");
    std::cout << "/";
    std::cout << "window:" << id << "\n";
    pickerPtr->quit();
}

int main(int argc, char* argv[]) {
    qputenv("QT_LOGGING_RULES", "qml=false");
    // Session-wide QT_SCALE_FACTOR (e.g. 1.667) would blow up a "fixed" dialog.
    // This picker is already sized in real pixels via setFixedSize + Hyprland rules.
    qunsetenv("QT_SCALE_FACTOR");
    qunsetenv("QT_SCREEN_SCALE_FACTORS");
    qunsetenv("QT_FONT_DPI");
    qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "0");
    qputenv("QT_ENABLE_HIGHDPI_SCALING", "0");

    bool allowTokenByDefault = false;
    for (int i = 1; i < argc; ++i) {
        if (argv[i] == std::string{"--allow-token"})
            allowTokenByDefault = true;
    }

    const char* WINDOWLISTSTR = getenv("XDPH_WINDOW_SHARING_LIST");
    const auto  WINDOWLIST    = getWindows(WINDOWLISTSTR);

    QApplication picker(argc, argv);
    pickerPtr = &picker;

    const QString fontFamily = pickUiFont();
    QFont         appFont(fontFamily, 11);
    appFont.setStyleStrategy(QFont::PreferAntialias);
    picker.setFont(appFont);
    picker.setStyleSheet(pickerStyleSheet(fontFamily));

    MainPicker w;
    mainPickerPtr = &w;
    w.setWindowTitle(QStringLiteral("Share"));

    // Fixed dialog size — content scrolls inside tabs; never user-resizable.
    constexpr int kPickerW = 560;
    constexpr int kPickerH = 440;
    w.setFixedSize(kPickerW, kPickerH);
    w.setMinimumSize(kPickerW, kPickerH);
    w.setMaximumSize(kPickerW, kPickerH);
    w.setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
    w.setWindowFlags(Qt::Dialog | Qt::CustomizeWindowHint | Qt::WindowTitleHint | Qt::WindowCloseButtonHint);

    QCoreApplication::setApplicationName("org.hyprland.xdg-desktop-portal-hyprland");

    auto* central = w.findChild<QWidget*>("centralwidget");
    auto* outer   = central ? central->findChild<QVBoxLayout*>("verticalLayout") : nullptr;

    // Hero header above the tabs
    if (outer) {
        auto* hero = new QWidget(&w);
        auto* heroLayout = new QVBoxLayout(hero);
        heroLayout->setContentsMargins(4, 2, 4, 10);
        heroLayout->setSpacing(4);

        auto* title = new QLabel(QStringLiteral("Share your screen"), hero);
        title->setObjectName("heroTitle");
        auto* subtitle = new QLabel(QStringLiteral("Choose a display, window, or region for this app."), hero);
        subtitle->setObjectName("heroSubtitle");
        subtitle->setWordWrap(true);

        heroLayout->addWidget(title);
        heroLayout->addWidget(subtitle);
        outer->insertWidget(0, hero);
    }

    const auto TABWIDGET        = w.findChild<QTabWidget*>("tabWidget");
    const auto ALLOWTOKENBUTTON = w.findChild<QCheckBox*>("checkBox");

    TABWIDGET->setDocumentMode(true);
    TABWIDGET->setElideMode(Qt::ElideNone);
    TABWIDGET->setTabText(0, QStringLiteral("Displays"));
    TABWIDGET->setTabText(1, QStringLiteral("Windows"));
    TABWIDGET->setTabText(2, QStringLiteral("Region"));

    ALLOWTOKENBUTTON->setText(QStringLiteral("Remember this choice for the app"));
    ALLOWTOKENBUTTON->setToolTip(
        QStringLiteral("Gives the app a restore token so it can skip this prompt next time.\n"
                       "Only enable this for apps you trust."));

    if (allowTokenByDefault)
        ALLOWTOKENBUTTON->setCheckState(Qt::CheckState::Checked);

    const auto TAB1 = (QWidget*)TABWIDGET->children()[0];

    const auto SCREENS_SCROLL_AREA_CONTENTS =
        (QWidget*)TAB1->findChild<QWidget*>("screens")->findChild<QScrollArea*>("scrollArea")->findChild<QWidget*>("scrollAreaWidgetContents");
    const auto SCREENS_SCROLL_AREA_CONTENTS_LAYOUT = SCREENS_SCROLL_AREA_CONTENTS->layout();
    SCREENS_SCROLL_AREA_CONTENTS_LAYOUT->setSpacing(8);
    SCREENS_SCROLL_AREA_CONTENTS_LAYOUT->setContentsMargins(4, 4, 4, 4);

    const auto SCREENS = picker.screens();

    for (int i = 0; i < SCREENS.size(); ++i) {
        const auto  GEOMETRY   = SCREENS[i]->geometry();
        const QString outName  = SCREENS[i]->name();
        const QString title    = outName.isEmpty() ? QStringLiteral("Display %1").arg(i) : outName;
        const QString subtitle = QStringLiteral("%1 × %2 · at %3, %4")
                                     .arg(GEOMETRY.width())
                                     .arg(GEOMETRY.height())
                                     .arg(GEOMETRY.x())
                                     .arg(GEOMETRY.y());

        auto* card = new SelectionCard(title, subtitle);
        SCREENS_SCROLL_AREA_CONTENTS_LAYOUT->addWidget(card);
        card->onClicked([=]() { emitScreenSelection(ALLOWTOKENBUTTON, outName); });
    }

    SCREENS_SCROLL_AREA_CONTENTS_LAYOUT->addItem(new QSpacerItem(0, 10000, QSizePolicy::Expanding, QSizePolicy::Expanding));

    const auto WINDOWS_SCROLL_AREA_CONTENTS =
        (QWidget*)TAB1->findChild<QWidget*>("windows")->findChild<QScrollArea*>("scrollArea_2")->findChild<QWidget*>("scrollAreaWidgetContents_2");
    const auto WINDOWS_SCROLL_AREA_CONTENTS_LAYOUT = WINDOWS_SCROLL_AREA_CONTENTS->layout();
    WINDOWS_SCROLL_AREA_CONTENTS_LAYOUT->setSpacing(8);
    WINDOWS_SCROLL_AREA_CONTENTS_LAYOUT->setContentsMargins(4, 4, 4, 4);

    if (WINDOWLIST.empty()) {
        auto* empty = new QLabel(QStringLiteral("No shareable windows right now."), WINDOWS_SCROLL_AREA_CONTENTS);
        empty->setObjectName("heroSubtitle");
        empty->setAlignment(Qt::AlignCenter);
        empty->setMinimumHeight(80);
        WINDOWS_SCROLL_AREA_CONTENTS_LAYOUT->addWidget(empty);
    }

    for (auto& window : WINDOWLIST) {
        const QString title    = QString::fromStdString(window.name.empty() ? window.clazz : window.name);
        const QString subtitle = QString::fromStdString(window.clazz);
        auto*         card     = new SelectionCard(title, subtitle == title ? QString() : subtitle);
        WINDOWS_SCROLL_AREA_CONTENTS_LAYOUT->addWidget(card);

        const auto windowId = window.id;
        mainPickerPtr->windowIDs[card] = static_cast<int>(windowId);

        card->onClicked([=]() { emitWindowSelection(ALLOWTOKENBUTTON, windowId); });
    }

    WINDOWS_SCROLL_AREA_CONTENTS_LAYOUT->addItem(new QSpacerItem(0, 10000, QSizePolicy::Expanding, QSizePolicy::Expanding));

    const auto REGION_OBJECT = (QWidget*)TAB1->findChild<QWidget*>("region");
    const auto REGION_LAYOUT = REGION_OBJECT->layout();

    auto* regionPanel = new QWidget(REGION_OBJECT);
    regionPanel->setObjectName("regionHint");
    auto* regionPanelLayout = new QVBoxLayout(regionPanel);
    regionPanelLayout->setContentsMargins(18, 18, 18, 18);
    regionPanelLayout->setSpacing(12);

    auto* regionTitle = new QLabel(QStringLiteral("Capture a region"), regionPanel);
    regionTitle->setObjectName("cardTitle");
    auto* regionBody = new QLabel(
        QStringLiteral("Click below, then drag on your desktop to select the area to share."),
        regionPanel);
    regionBody->setObjectName("cardSubtitle");
    regionBody->setWordWrap(true);

    auto* regionCard = new SelectionCard(QStringLiteral("Select region…"), QStringLiteral("Uses slurp on your desktop"));
    regionPanelLayout->addWidget(regionTitle);
    regionPanelLayout->addWidget(regionBody);
    regionPanelLayout->addWidget(regionCard);
    regionPanelLayout->addStretch(1);
    REGION_LAYOUT->addWidget(regionPanel);

    regionCard->onClicked([=]() {
        auto REGION = execAndGet("slurp -f \"%o %x %y %w %h\"");
        REGION      = REGION.substr(0, REGION.length());

        QScreen* pScreen = nullptr;
        if (REGION.find_first_of(' ') == std::string::npos) {
            std::cout << "error1\n";
            pickerPtr->quit();
            return;
        }
        const auto SCREEN_NAME = REGION.substr(0, REGION.find_first_of(' '));

        for (auto& screen : SCREENS) {
            if (screen->name().toStdString() == SCREEN_NAME) {
                pScreen = screen;
                break;
            }
        }

        if (!pScreen) {
            std::cout << "error2\n";
            pickerPtr->quit();
            return;
        }

        try {
            REGION       = REGION.substr(REGION.find_first_of(' ') + 1);
            const auto X = std::stoi(REGION.substr(0, REGION.find_first_of(' ')));
            REGION       = REGION.substr(REGION.find_first_of(' ') + 1);
            const auto Y = std::stoi(REGION.substr(0, REGION.find_first_of(' ')));
            REGION       = REGION.substr(REGION.find_first_of(' ') + 1);
            const auto W = std::stoi(REGION.substr(0, REGION.find_first_of(' ')));
            REGION       = REGION.substr(REGION.find_first_of(' ') + 1);
            const auto H = std::stoi(REGION);

            std::cout << "[SELECTION]";
            std::cout << (ALLOWTOKENBUTTON->isChecked() ? "r" : "");
            std::cout << "/";
            std::cout << "region:" << SCREEN_NAME << "@" << X - pScreen->geometry().x() << "," << Y - pScreen->geometry().y() << "," << W << "," << H << "\n";

            pickerPtr->quit();
        } catch (...) {
            std::cout << "error3\n";
            pickerPtr->quit();
        }
    });

    // Center on the focused/primary screen (Hyprland rule also forces float+center).
    QScreen* target = w.screen();
    if (!target)
        target = QGuiApplication::primaryScreen();
    if (target) {
        const QRect ag = target->availableGeometry();
        w.move(ag.x() + (ag.width() - w.width()) / 2, ag.y() + (ag.height() - w.height()) / 2);
    }

    w.show();
    w.setFixedSize(kPickerW, kPickerH);
    w.raise();
    w.activateWindow();
    return picker.exec();
}
