/*
  Copyright (C) 2013 Jolla Ltd.
  Contact: Thomas Perl <thomas.perl@jollamobile.com>
  All rights reserved.

  You may use this file under the terms of BSD license as follows:

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright
	  notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.
	* Neither the name of the Jolla Ltd nor the
	  names of its contributors may be used to endorse or promote products
	  derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QQuickView>
#include <QScopedPointer>
#include <QStandardPaths>
#include <QtQml>

#include <sailfishapp.h>

#include "backupfile.h"


static bool copyDir(const QString &from, const QString &to)
{
	if (!QDir().mkpath(to))
		return false;
	const QFileInfoList entries = QDir(from).entryInfoList(
		QDir::Dirs | QDir::Files | QDir::Hidden | QDir::NoDotAndDotDot);
	for (const QFileInfo &fi : entries) {
		const QString target = to + QLatin1Char('/') + fi.fileName();
		if (fi.isDir() ? !copyDir(fi.filePath(), target)
		               : !QFile::copy(fi.filePath(), target))
			return false;
	}
	return true;
}

// Before Sailjail the database lived in ~/.local/share/harbour-luna/harbour-luna.
// Copy it to the sandboxed data location once; the old copy is removed only
// after the new one is complete.
static void migrateOfflineStorage(const QString &newPath)
{
	const QString oldBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
		+ QStringLiteral("/harbour-luna/harbour-luna");
	const QString oldPath = oldBase + QStringLiteral("/QML/OfflineStorage");
	if (QDir(oldPath) == QDir(newPath) || !QFileInfo::exists(oldPath) || QFileInfo::exists(newPath))
		return;

	const QString tmpPath = newPath + QStringLiteral(".migrating");
	QDir(tmpPath).removeRecursively();
	if (copyDir(oldPath, tmpPath) && QDir().rename(tmpPath, newPath)) {
		QDir(oldBase).removeRecursively();
		QDir().rmdir(QFileInfo(oldBase).path());
	} else {
		qWarning("Could not migrate data from %s", qPrintable(oldPath));
		QDir(tmpPath).removeRecursively();
	}
}


int main(int argc, char *argv[])
{
	QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
	app->setApplicationVersion(QStringLiteral(APP_VERSION));

	qmlRegisterType<BackupFile>("harbour.luna", 1, 0, "BackupFile");

	QScopedPointer<QQuickView> view(SailfishApp::createView());
	migrateOfflineStorage(view->engine()->offlineStoragePath());
	view->setSource(SailfishApp::pathToMainQml());
	view->show();

	return app->exec();
}

