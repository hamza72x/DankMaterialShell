#include "mainpicker.h"
#include "./ui_mainpicker.h"
#include <QDebug>

MainPicker::MainPicker(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainPicker)
{
    ui->setupUi(this);
    // Match the fixed dialog size used by main.cpp / Hyprland window rules.
    setFixedSize(560, 440);
}

MainPicker::~MainPicker()
{
    delete ui;
}

void MainPicker::showEvent(QShowEvent* event)
{
    QMainWindow::showEvent(event);
    // Wayland can ignore the initial size hint; clamp again on map.
    setFixedSize(560, 440);
}

void MainPicker::onMonitorButtonClicked(QObject* target, QEvent* event) {
    qDebug() << "click";
}
