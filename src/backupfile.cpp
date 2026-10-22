#include "backupfile.h"

#include <QDate>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QSaveFile>
#include <QStandardPaths>
#include <QtConcurrent/QtConcurrentRun>

#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/rand.h>

namespace {

// Matches `openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -md sha256`
const QByteArray Magic("Salted__");
const int SaltLen = 8;
const int KeyLen = 32;
const int IvLen = 16;
const int Iterations = 200000;
const qint64 MaxFileSize = 20 * 1024 * 1024;

struct Result {
    QString value;
    QString error;
};

Result failure(const char *error)
{
    return Result{QString(), QString::fromLatin1(error)};
}

bool deriveKeyIv(const QByteArray &password, const unsigned char *salt, unsigned char *keyIv)
{
    return PKCS5_PBKDF2_HMAC(password.constData(), password.size(), salt, SaltLen,
                             Iterations, EVP_sha256(), KeyLen + IvLen, keyIv) == 1;
}

bool aes256cbc(bool encrypt, const unsigned char *keyIv, const QByteArray &in, QByteArray &out)
{
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return false;
    out.resize(in.size() + EVP_MAX_BLOCK_LENGTH);
    unsigned char *outData = reinterpret_cast<unsigned char *>(out.data());
    int len = 0;
    int finalLen = 0;
    bool ok = EVP_CipherInit_ex(ctx, EVP_aes_256_cbc(), nullptr, keyIv, keyIv + KeyLen,
                                encrypt ? 1 : 0) == 1
            && EVP_CipherUpdate(ctx, outData, &len,
                                reinterpret_cast<const unsigned char *>(in.constData()),
                                in.size()) == 1
            && EVP_CipherFinal_ex(ctx, outData + len, &finalLen) == 1;
    EVP_CIPHER_CTX_free(ctx);
    out.resize(ok ? len + finalLen : 0);
    return ok;
}

Result saveFile(const QString &path, const QString &content, const QString &password)
{
    QByteArray data = content.toUtf8();
    if (!password.isEmpty()) {
        unsigned char salt[SaltLen];
        unsigned char keyIv[KeyLen + IvLen];
        QByteArray cipher;
        bool ok = RAND_bytes(salt, SaltLen) == 1
                && deriveKeyIv(password.toUtf8(), salt, keyIv)
                && aes256cbc(true, keyIv, data, cipher);
        OPENSSL_cleanse(keyIv, sizeof(keyIv));
        if (!ok)
            return failure("crypto");
        data = Magic + QByteArray(reinterpret_cast<const char *>(salt), SaltLen) + cipher;
    }

    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return failure("io");
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    if (file.write(data) != data.size() || !file.commit())
        return failure("io");
    return Result{path, QString()};
}

Result loadFile(const QString &path, const QString &password)
{
    QFile file(path);
    if (file.size() > MaxFileSize)
        return failure("too_large");
    if (!file.open(QIODevice::ReadOnly))
        return failure("io");
    QByteArray data = file.readAll();

    if (data.startsWith(Magic)) {
        if (data.size() <= Magic.size() + SaltLen)
            return failure("invalid");
        const unsigned char *salt =
                reinterpret_cast<const unsigned char *>(data.constData()) + Magic.size();
        unsigned char keyIv[KeyLen + IvLen];
        QByteArray plain;
        bool derived = deriveKeyIv(password.toUtf8(), salt, keyIv);
        bool ok = derived
                && aes256cbc(false, keyIv, data.mid(Magic.size() + SaltLen), plain);
        OPENSSL_cleanse(keyIv, sizeof(keyIv));
        if (!derived)
            return failure("crypto");
        if (!ok)
            return failure("wrong_password");
        data = plain;
    }
    return Result{QString::fromUtf8(data), QString()};
}

} // namespace

BackupFile::BackupFile(QObject *parent)
    : QObject(parent)
    , m_busy(false)
{
}

QString BackupFile::suggestedPath(bool encrypted) const
{
    QDir dir(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation));
    QString base = QStringLiteral("harbour-luna-") + QDate::currentDate().toString(Qt::ISODate);
    QString ext = encrypted ? QStringLiteral(".json.enc") : QStringLiteral(".json");
    QString path = dir.filePath(base + ext);
    for (int i = 2; QFile::exists(path); ++i)
        path = dir.filePath(QStringLiteral("%1-%2%3").arg(base).arg(i).arg(ext));
    return path;
}

bool BackupFile::isEncrypted(const QString &path) const
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) && file.read(Magic.size()) == Magic;
}

void BackupFile::save(const QString &path, const QString &content, const QString &password)
{
    if (m_busy)
        return;
    setBusy(true);
    QFutureWatcher<Result> *watcher = new QFutureWatcher<Result>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher]() {
        Result result = watcher->result();
        watcher->deleteLater();
        setBusy(false);
        emit saved(result.value, result.error);
    });
    watcher->setFuture(QtConcurrent::run(saveFile, path, content, password));
}

void BackupFile::load(const QString &path, const QString &password)
{
    if (m_busy)
        return;
    setBusy(true);
    QFutureWatcher<Result> *watcher = new QFutureWatcher<Result>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher]() {
        Result result = watcher->result();
        watcher->deleteLater();
        setBusy(false);
        emit loaded(result.value, result.error);
    });
    watcher->setFuture(QtConcurrent::run(loadFile, path, password));
}

void BackupFile::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
    }
}
