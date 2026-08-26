#ifndef SELECTIONCARD_H
#define SELECTIONCARD_H

#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QVBoxLayout>
#include <QMouseEvent>
#include <QKeyEvent>
#include <QEnterEvent>
#include <QStyle>
#include <functional>

class SelectionCard : public QFrame {
public:
    explicit SelectionCard(const QString& title, const QString& subtitle, QWidget* parent = nullptr)
        : QFrame(parent) {
        setObjectName("selectionCard");
        setCursor(Qt::PointingHandCursor);
        setFocusPolicy(Qt::StrongFocus);
        setAttribute(Qt::WA_Hover, true);

        auto* root = new QHBoxLayout(this);
        root->setContentsMargins(16, 14, 16, 14);
        root->setSpacing(14);

        auto* textCol = new QVBoxLayout();
        textCol->setSpacing(2);
        textCol->setContentsMargins(0, 0, 0, 0);

        m_title = new QLabel(title, this);
        m_title->setObjectName("cardTitle");
        m_title->setWordWrap(false);

        m_subtitle = new QLabel(subtitle, this);
        m_subtitle->setObjectName("cardSubtitle");
        m_subtitle->setWordWrap(false);

        textCol->addWidget(m_title);
        if (!subtitle.isEmpty())
            textCol->addWidget(m_subtitle);
        else
            m_subtitle->hide();

        root->addLayout(textCol, 1);

        m_chevron = new QLabel(QStringLiteral("›"), this);
        m_chevron->setObjectName("cardChevron");
        m_chevron->setAlignment(Qt::AlignCenter);
        root->addWidget(m_chevron, 0, Qt::AlignVCenter);

        setMinimumHeight(subtitle.isEmpty() ? 52 : 64);
        setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    }

    void onClicked(std::function<void()> cb) { m_onClicked = std::move(cb); }

protected:
    void mouseReleaseEvent(QMouseEvent* event) override {
        if (event->button() == Qt::LeftButton && rect().contains(event->pos()) && m_onClicked)
            m_onClicked();
        QFrame::mouseReleaseEvent(event);
    }

    void keyPressEvent(QKeyEvent* event) override {
        if ((event->key() == Qt::Key_Return || event->key() == Qt::Key_Enter || event->key() == Qt::Key_Space) && m_onClicked) {
            m_onClicked();
            return;
        }
        QFrame::keyPressEvent(event);
    }

    void enterEvent(QEnterEvent* event) override {
        setProperty("hovered", true);
        style()->unpolish(this);
        style()->polish(this);
        QFrame::enterEvent(event);
    }

    void leaveEvent(QEvent* event) override {
        setProperty("hovered", false);
        style()->unpolish(this);
        style()->polish(this);
        QFrame::leaveEvent(event);
    }

private:
    QLabel*                 m_title      = nullptr;
    QLabel*                 m_subtitle   = nullptr;
    QLabel*                 m_chevron    = nullptr;
    std::function<void()>   m_onClicked;
};

#endif // SELECTIONCARD_H
