/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "keysignaturesettingsmodel.h"

#include <algorithm>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "engraving/dom/keysig.h"
#include "engraving/dom/measure.h"
#include "engraving/dom/layoutbreak.h"
#include "engraving/dom/score.h"
#include "engraving/editing/persiankeysig.h"

#include "notation/inotation.h"
#include "notation/inotationelements.h"
#include "notation/inotationundostack.h"
#include "project/inotationproject.h"

#include "settings.h"
#include "translation.h"
#include "types/translatablestring.h"

using namespace mu::propertiespanel;

static const muse::Settings::Key kPersianKeyByScore("persianTuner", "keySigByScore");
static const muse::Settings::Key kPersianTuningTable("persianTuner", "tuningTable");

KeySignatureSettingsModel::KeySignatureSettingsModel(QObject* parent, const muse::modularity::ContextPtr& iocCtx,
                                                     IElementRepositoryService* repository)
    : PropertiesPanelAbstractModel(parent, iocCtx, repository)
{
    setModelType(PropertiesPanelModelType::TYPE_KEYSIGNATURE);
    setTitle(muse::qtrc("propertiespanel", "Key signature"));
    setIcon(muse::ui::IconCode::Code::KEY_SIGNATURE);
    createProperties();
}

void KeySignatureSettingsModel::createProperties()
{
    m_hasToShowCourtesy = buildPropertyItem(mu::engraving::Pid::SHOW_COURTESY);
    m_mode = buildPropertyItem(mu::engraving::Pid::KEYSIG_MODE);
}

void KeySignatureSettingsModel::requestElements()
{
    m_elementList = m_repository->findElementsByType(mu::engraving::ElementType::KEYSIG);
}

void KeySignatureSettingsModel::loadProperties()
{
    loadPropertyItem(m_hasToShowCourtesy);
    loadPropertyItem(m_mode);

    bool enableMode = true;
    bool enableCourtesy = true;

    for (const mu::engraving::EngravingItem* element : m_elementList) {
        if (element->generated() || toKeySig(element)->isCourtesy()) {
            enableMode = false;
        }

        const engraving::Measure* measure = element->findMeasure();
        const engraving::Measure* prevMeasure = measure ? measure->prevMeasure() : nullptr;
        const engraving::LayoutBreak* sectionBreak = prevMeasure ? prevMeasure->sectionBreakElement() : nullptr;
        if (sectionBreak && !sectionBreak->showCourtesy()) {
            enableCourtesy = false;
        }
    }

    m_hasToShowCourtesy->setIsEnabled(enableCourtesy);
    m_mode->setIsEnabled(enableMode);

    refreshPersianKey();
}

PropertyItem* KeySignatureSettingsModel::hasToShowCourtesy() const
{
    return m_hasToShowCourtesy;
}

PropertyItem* KeySignatureSettingsModel::mode() const
{
    return m_mode;
}

QVariantList KeySignatureSettingsModel::persianKeyPatterns() const
{
    QVariantList rows;
    for (const engraving::PersianKeySig& keySig : engraving::predefinedPersianKeySigs()) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), QString::fromStdString(keySig.id));
        row.insert(QStringLiteral("nameEn"), QString::fromStdString(keySig.nameEn));
        row.insert(QStringLiteral("nameFa"), QString::fromStdString(keySig.nameFa));

        QStringList parts;
        for (const engraving::PersianKeySigNote& n : keySig.notes) {
            parts << QString::fromStdString(n.letter) + " " + QString::fromStdString(n.variant);
        }
        row.insert(QStringLiteral("description"), parts.join(QStringLiteral(", ")));
        rows << row;
    }
    return rows;
}

int KeySignatureSettingsModel::persianKeyPatternIndex() const
{
    if (m_persianKeyPatternId.isEmpty()) {
        return -1;
    }
    const int idx = std::find_if(engraving::predefinedPersianKeySigs().begin(), engraving::predefinedPersianKeySigs().end(),
                                 [id = m_persianKeyPatternId.toStdString()] (const engraving::PersianKeySig& keySig) {
                                     return keySig.id == id;
                                 }) - engraving::predefinedPersianKeySigs().begin();
    return idx >= 0 && idx < (int)engraving::predefinedPersianKeySigs().size() ? idx : -1;
}

QString KeySignatureSettingsModel::persianKeyPatternDescription() const
{
    const engraving::PersianKeySig* pattern = m_persianKeyPatternId.isEmpty()
                                              ? nullptr : engraving::persianKeySigById(m_persianKeyPatternId.toStdString());
    if (!pattern) {
        return QString();
    }
    QStringList parts;
    for (const engraving::PersianKeySigNote& n : pattern->notes) {
        parts << QString::fromStdString(n.letter) + " " + QString::fromStdString(n.variant);
    }
    return parts.isEmpty() ? QStringLiteral("natural") : parts.join(QStringLiteral(", "));
}

bool KeySignatureSettingsModel::hasPersianKey() const
{
    return !m_persianKeyPatternId.isEmpty();
}

void KeySignatureSettingsModel::setPersianKeyPatternIndex(int index)
{
    const auto& keySigs = engraving::predefinedPersianKeySigs();
    if (index >= 0 && index < (int)keySigs.size()) {
        applyPersianKeyPattern(QString::fromStdString(keySigs[index].id));
    } else {
        applyPersianKeyPattern(QString());
    }
}

void KeySignatureSettingsModel::applyPersianKey()
{
    applyPersianKeyPattern(m_persianKeyPatternId);
}

void KeySignatureSettingsModel::clearPersianKey()
{
    applyPersianKeyPattern(QString());
}

void KeySignatureSettingsModel::refreshPersianKey()
{
    m_persianKeyPatternId = persianKeyPatternId();
    emit persianKeyPatternIndexChanged();
}

QString KeySignatureSettingsModel::persianKeyPatternId() const
{
    auto project = context()->currentProject();
    if (!project) {
        return QString();
    }
    const QString scoreId = project->displayName();

    const QString json = muse::settings()->value(kPersianKeyByScore).toQString();
    const QJsonObject obj = QJsonDocument::fromJson(json.toUtf8()).object();
    const QString id = obj.value(scoreId).toString();
    return engraving::persianKeySigById(id.toStdString()) ? id : QString();
}

void KeySignatureSettingsModel::applyPersianKeyPattern(const QString& patternId)
{
    mu::notation::INotationPtr n = context()->currentNotation();
    if (!n || !n->elements()) {
        return;
    }
    engraving::Score* sc = n->elements()->msScore();
    if (!sc || !n->undoStack()) {
        return;
    }

    const engraving::PersianKeySig* pattern = patternId.isEmpty() ? nullptr
                                                                  : engraving::persianKeySigById(patternId.toStdString());

    std::vector<engraving::PersianKeySigNote> mapping;
    if (pattern) {
        mapping = pattern->notes;
    }

    // Use the cents the user has set in the Persian tuner, when available
    const QString tableJson = muse::settings()->value(kPersianTuningTable).toQString();
    const QJsonObject tableObj = QJsonDocument::fromJson(tableJson.toUtf8()).object();
    auto centsFor = [tableObj] (const std::string& letter, const std::string& variant) -> double {
        const QJsonObject variants = tableObj.value(QString::fromStdString(letter)).toObject();
        const QJsonValue v = variants.value(QString::fromStdString(variant));
        if (v.isDouble()) {
            return v.toDouble();
        }
        return engraving::defaultPersianVariantCents(variant);
    };

    n->undoStack()->prepareChanges(
        pattern ? mu::TranslatableString("undoableAction", "Apply Persian key signature %1").arg(
                      mu::String(QString::fromStdString(pattern->nameEn)))
                : mu::TranslatableString("undoableAction", "Clear Persian key signature"));
    engraving::EditPersianKeySig::applyScoreKeySig(sc, mapping, centsFor);
    n->undoStack()->commitChanges();
    n->notationChanged().send(muse::RectF());

    // Keep the pattern in the shared settings (the Persian tuner shows it too)
    auto project = context()->currentProject();
    const QString scoreId = project ? project->displayName() : QString();
    if (!scoreId.isEmpty()) {
        const QString json = muse::settings()->value(kPersianKeyByScore).toQString();
        QJsonObject obj = QJsonDocument::fromJson(json.toUtf8()).object();
        if (patternId.isEmpty()) {
            obj.remove(scoreId);
        } else {
            obj.insert(scoreId, patternId);
        }
        muse::settings()->setSharedValue(kPersianKeyByScore,
                                                                    muse::Val(QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact))));
    }

    refreshPersianKey();
}
