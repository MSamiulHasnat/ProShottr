#pragma once

#include <QImage>
#include <QObject>

struct DepthOptions
{
    bool enableDepth = true;
    int shadowRadius = 24;
    double shadowOpacity = 0.35;
    int blurRadius = 8;
    int cornerRadius = 18;
};

class DepthStyler : public QObject
{
    Q_OBJECT
public:
    explicit DepthStyler(QObject *parent = nullptr);

    QImage apply(const QImage &source, const DepthOptions &options) const;

private:
    QImage applyShadow(const QImage &source, const DepthOptions &options) const;
};