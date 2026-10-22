#ifndef BACKUPFILE_H
#define BACKUPFILE_H

#include <QObject>
#include <QString>

// Reads and writes backup files, optionally encrypted with a password.
// Encrypted files use the `openssl enc -aes-256-cbc -pbkdf2 -md sha256`
// layout, so they can also be decrypted on a PC.
class BackupFile : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit BackupFile(QObject *parent = nullptr);

    bool busy() const { return m_busy; }

    Q_INVOKABLE QString suggestedPath(bool encrypted) const;
    Q_INVOKABLE bool isEncrypted(const QString &path) const;

    // Both run in a worker thread and report through saved()/loaded().
    // An empty password means the file is (or is written) unencrypted.
    Q_INVOKABLE void save(const QString &path, const QString &content, const QString &password);
    Q_INVOKABLE void load(const QString &path, const QString &password);

signals:
    void busyChanged();
    // error is empty on success, otherwise one of:
    // "io", "crypto", "wrong_password", "too_large", "invalid"
    void saved(const QString &path, const QString &error);
    void loaded(const QString &content, const QString &error);

private:
    void setBusy(bool busy);

    bool m_busy;
};

#endif // BACKUPFILE_H
