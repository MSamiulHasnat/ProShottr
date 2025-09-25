#include "DepthStyler.hpp"

#include <QGraphicsBlurEffect>
#include <QGraphicsPixmapItem>
#include <QGraphicsScene>
#include <QPainter>
#include <QPainterPath>

DepthStyler::DepthStyler(QObject *parent)
    : QObject(parent)
{
}

QImage DepthStyler::apply(const QImage &source, const DepthOptions &options) const
{
    if (source.isNull() || !options.enableDepth) {
        return source;
    }
    return applyShadow(source, options);
}

QImage DepthStyler::applyShadow(const QImage &source, const DepthOptions &options) const
{
    const int margin = qMax(16, options.shadowRadius * 2 + options.blurRadius * 2);
    const QSize resultSize = source.size() + QSize(margin * 2, margin * 2);
    QImage result(resultSize, QImage::Format_ARGB32_Premultiplied);
    result.fill(Qt::transparent);

    const QRect targetRect(margin, margin, source.width(), source.height());

    QPainter painter(&result);
    painter.setRenderHint(QPainter::Antialiasing, true);

    if (options.shadowRadius > 0) {
        QImage shadowMask(source.size(), QImage::Format_ARGB32_Premultiplied);
        shadowMask.fill(Qt::transparent);

        {
            QPainter shadowPainter(&shadowMask);
            shadowPainter.setRenderHint(QPainter::Antialiasing, true);
            QPainterPath maskPath;
            maskPath.addRoundedRect(QRectF(QPointF(0, 0), source.size()), options.cornerRadius, options.cornerRadius);
            QColor shadowColor(0, 0, 0, static_cast<int>(options.shadowOpacity * 255.0));
            shadowPainter.fillPath(maskPath, shadowColor);
        }

        QGraphicsScene scene;
        auto *pixmapItem = new QGraphicsPixmapItem(QPixmap::fromImage(shadowMask));
        auto *blurEffect = new QGraphicsBlurEffect;
        blurEffect->setBlurRadius(static_cast<qreal>(options.shadowRadius));
        pixmapItem->setGraphicsEffect(blurEffect);
        scene.addItem(pixmapItem);

        const QRectF renderTarget(
            -options.shadowRadius * 2,
            -options.shadowRadius * 2,
            shadowMask.width() + options.shadowRadius * 4,
            shadowMask.height() + options.shadowRadius * 4);

        QImage blurred(renderTarget.size().toSize(), QImage::Format_ARGB32_Premultiplied);
        blurred.fill(Qt::transparent);
        QPainter blurPainter(&blurred);
        scene.render(&blurPainter, QRectF(blurred.rect()), renderTarget);
        blurPainter.end();

        painter.drawImage(targetRect.topLeft() - QPoint(options.shadowRadius, options.shadowRadius), blurred);
    }

    if (options.cornerRadius > 0) {
        QPainterPath clipPath;
        clipPath.addRoundedRect(QRectF(targetRect), options.cornerRadius, options.cornerRadius);
        painter.setClipPath(clipPath);
    }

    painter.drawImage(targetRect, source);
    painter.end();

    return result;
}
