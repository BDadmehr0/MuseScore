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
#include <map>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "engraving/dom/keysig.h"
#include "engraving/dom/masterscore.h"
#include "engraving/dom/measure.h"
#include "engraving/dom/layoutbreak.h"
#include "engraving/dom/score.h"
#include "engraving/dom/staff.h"
#include "engraving/editing/persiankeysig.h"
#include "engraving/editing/transaction/transaction.h"

#include "notation/inotation.h"
#include "notation/inotationelements.h"
#include "notation/inotationundostack.h"
#include "project/inotationproject.h"

#include "settings.h"
#include "translation.h"
#include "types/translatablestring.h"

using namespace mu::propertiespanel;

static const muse::Settings::Key kPersianKeyByScore("persianTuner", "keySigByScore");
static const muse::Settings::Key kPersianKeyCustom("persianTuner", "keySigCustom");
static const muse::Settings::Key kPersianTuningTable("persianTuner", "tuningTable");

namespace {
const std::vector<std::string> kLetters = { "C", "D", "E", "F", "G", "A", "B" };
// Order shown in the UI: natural, flat, koron, sori, sharp
const std::vector<std::string> kVariants = { "natural", "flat", "koron", "sori", "sharp" };

QString letterSource(const std::string& letter)
{
    static const std::map<std::string, QString> names = {
        { "C", "Do" }, { "D", "Re" }, { "E", "Mi" }, { "F", "Fa" },
        { "G", "Sol" }, { "A", "La" }, { "B", "Si" }
    };
    auto it = names.find(letter);
    return it == names.end() ? QString::fromStdString(letter) : it->second;
}

int variantIndex(const std::string& variant)
{
    for (size_t i = 0; i < kVariants.size(); ++i) {
        if (kVariants[i] == variant) {
            return static_cast<int>(i);
        }
    }
    return 0;
}

std::vector<const mu::engraving::PersianKeySig*> visiblePersianKeyPatterns()
{
    std::vector<const mu::engraving::PersianKeySig*> result;
    for (const mu::engraving::PersianKeySig& keySig : mu::engraving::predefinedPersianKeySigs()) {
        if (!mu::engraving::isLegacyPersianKeySigId(keySig.id)) {
            result.push_back(&keySig);
        }
    }
    return result;
}
}

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
        if (element->generated() || mu::engraving::toKeySig(element)->isCourtesy()) {
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
        if (engraving::isLegacyPersianKeySigId(keySig.id)) {
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("id"), QString::fromStdString(keySig.id));
        row.insert(QStringLiteral("nameEn"), QString::fromStdString(keySig.nameEn));
        row.insert(QStringLiteral("nameFa"), QString::fromStdString(keySig.nameFa));

        QStringList parts;
        for (const engraving::PersianKeySigNote& n : keySig.notes) {
            parts << letterSource(n.letter) + " " + QString::fromStdString(n.variant);
        }
        row.insert(QStringLiteral("description"), parts.join(QStringLiteral(", ")));
        rows << row;
    }
    return rows;
}

int KeySignatureSettingsModel::persianKeyPatternIndex() const
{
    const auto patterns = visiblePersianKeyPatterns();
    if (m_persianKeyPatternId.isEmpty()) {
        return -1;
    }
    static const QString customId = QStringLiteral("custom");
    if (m_persianKeyPatternId == customId) {
        return static_cast<int>(patterns.size());
    }
    const auto it = std::find_if(patterns.begin(), patterns.end(),
                                 [id = m_persianKeyPatternId.toStdString()] (const engraving::PersianKeySig* keySig) {
        return keySig->id == id;
    });
    return it == patterns.end() ? -1 : static_cast<int>(it - patterns.begin());
}

QString KeySignatureSettingsModel::persianKeyPatternDescription() const
{
    if (m_persianKeyPatternId == QLatin1String("custom")) {
        QStringList parts;
        for (int i = 0; i < m_customVariants.size(); ++i) {
            const int v = m_customVariants.value(i).toInt();
            if (v > 0) {
                parts << letterSource(kLetters[i]) + " " + QString::fromStdString(kVariants[v]);
            }
        }
        return parts.isEmpty() ? muse::qtrc("propertiespanel", "Custom — all notes natural")
               : muse::qtrc("propertiespanel", "Custom: %1").arg(parts.join(QStringLiteral(", ")));
    }
    const engraving::PersianKeySig* pattern = m_persianKeyPatternId.isEmpty()
                                              ? nullptr : engraving::persianKeySigById(m_persianKeyPatternId.toStdString());
    if (!pattern) {
        return QString();
    }
    QStringList parts;
    for (const engraving::PersianKeySigNote& n : pattern->notes) {
        parts << letterSource(n.letter) + " " + QString::fromStdString(n.variant);
    }
    return parts.isEmpty() ? QStringLiteral("natural") : parts.join(QStringLiteral(", "));
}

bool KeySignatureSettingsModel::hasPersianKey() const
{
    return !m_persianKeyPatternId.isEmpty();
}

QVariantList KeySignatureSettingsModel::letterNames() const
{
    QVariantList rows;
    for (const std::string& letter : kLetters) {
        rows << muse::qtrc("propertiespanel", muse::String(letterSource(letter)));
    }
    return rows;
}

QVariantList KeySignatureSettingsModel::variantNames() const
{
    QVariantList rows;
    for (const std::string& variant : kVariants) {
        QString name;
        if (variant == "natural") {
            name = muse::qtrc("propertiespanel", "Natural");
        } else if (variant == "flat") {
            name = muse::qtrc("propertiespanel", "Flat");
        } else if (variant == "koron") {
            name = muse::qtrc("propertiespanel", "Koron");
        } else if (variant == "sori") {
            name = muse::qtrc("propertiespanel", "Sori");
        } else {
            name = muse::qtrc("propertiespanel", "Sharp");
        }
        rows << name;
    }
    return rows;
}

QVariantList KeySignatureSettingsModel::customVariants() const
{
    return m_customVariants;
}

bool KeySignatureSettingsModel::isCustomPersianKey() const
{
    return m_persianKeyPatternId == QLatin1String("custom");
}

void KeySignatureSettingsModel::setPersianKeyPatternIndex(int index)
{
    const auto patterns = visiblePersianKeyPatterns();
    if (index == static_cast<int>(patterns.size())) {
        // "Custom" entry: switch to the current custom mapping (or all
        // naturals) without rebuilding it from a predefined pattern.
        applyPersianKeyPattern(QStringLiteral("custom"), storedCustomMapping());
        return;
    }
    if (index >= 0 && index < static_cast<int>(patterns.size())) {
        applyPersianKeyPattern(QString::fromStdString(patterns[index]->id));
    } else {
        applyPersianKeyPattern(QString());
    }
}

void KeySignatureSettingsModel::applyPersianKey()
{
    if (m_persianKeyPatternId == QLatin1String("custom")) {
        applyPersianKeyPattern(QStringLiteral("custom"), storedCustomMapping());
    } else {
        applyPersianKeyPattern(m_persianKeyPatternId);
    }
}

void KeySignatureSettingsModel::clearPersianKey()
{
    applyPersianKeyPattern(QString());
}

void KeySignatureSettingsModel::setCustomVariant(int letterIndex, int variantIndexIdx)
{
    if (letterIndex < 0 || letterIndex >= (int)kLetters.size()) {
        return;
    }
    if (variantIndexIdx < 0 || variantIndexIdx >= (int)kVariants.size()) {
        return;
    }

    QVariantMap mapping = storedCustomMapping();
    mapping.insert(QString::fromStdString(kLetters[letterIndex]), variantIndexIdx);
    applyPersianKeyPattern(QStringLiteral("custom"), mapping);
}

void KeySignatureSettingsModel::resetCustomKey()
{
    applyPersianKeyPattern(QStringLiteral("custom"), QVariantMap());
}

void KeySignatureSettingsModel::refreshPersianKey()
{
    m_persianKeyPatternId = persianKeyPatternId();
    setCustomVariantsFromPattern(m_persianKeyPatternId, m_persianKeyPatternId == QLatin1String("custom")
                                 ? storedCustomMapping() : QVariantMap());
    emit persianKeyPatternIndexChanged();
    emit customVariantsChanged();
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
    if (id == QLatin1String("custom")) {
        return id;
    }
    return engraving::persianKeySigById(id.toStdString()) ? id : QString();
}

QVariantMap KeySignatureSettingsModel::storedCustomMapping() const
{
    auto project = context()->currentProject();
    const QString scoreId = project ? project->displayName() : QString();
    if (scoreId.isEmpty()) {
        return QVariantMap();
    }
    const QString json = muse::settings()->value(kPersianKeyCustom).toQString();
    const QJsonObject root = QJsonDocument::fromJson(json.toUtf8()).object();
    return root.value(scoreId).toObject().toVariantMap();
}

void KeySignatureSettingsModel::setCustomVariantsFromPattern(const QString& patternId, const QVariantMap& customMapping)
{
    QVariantList variants;
    variants.reserve(int(kLetters.size()));
    std::map<std::string, std::string> patternNotes;
    if (patternId != QLatin1String("custom")) {
        if (const engraving::PersianKeySig* p = engraving::persianKeySigById(patternId.toStdString())) {
            for (const engraving::PersianKeySigNote& n : p->notes) {
                patternNotes[n.letter] = n.variant;
            }
        }
    }
    for (const std::string& letter : kLetters) {
        int v = 0;
        if (patternId == QLatin1String("custom")) {
            v = customMapping.value(QString::fromStdString(letter), 0).toInt();
            v = std::clamp(v, 0, int(kVariants.size()) - 1);
        } else if (patternNotes.count(letter)) {
            v = variantIndex(patternNotes.at(letter));
        }
        variants << v;
    }
    m_customVariants = variants;
}

void KeySignatureSettingsModel::applyPersianKeyPattern(const QString& patternId, const QVariantMap& customMapping)
{
    mu::notation::INotationPtr n = context()->currentNotation();
    if (!n || !n->elements()) {
        return;
    }
    engraving::Score* sc = n->elements()->msScore();
    if (!sc || !n->undoStack()) {
        return;
    }

    const bool isCustom = (patternId == QLatin1String("custom"));
    const engraving::PersianKeySig* pattern = (!isCustom && !patternId.isEmpty())
                                              ? engraving::persianKeySigById(patternId.toStdString())
                                              : nullptr;

    // Build the letter -> variant mapping.
    std::vector<engraving::PersianKeySigNote> mapping;
    if (pattern) {
        mapping = pattern->notes;
    } else if (isCustom) {
        for (int i = 0; i < (int)kLetters.size(); ++i) {
            const int v = customMapping.value(QString::fromStdString(kLetters[i]), 0).toInt();
            if (v > 0 && v < (int)kVariants.size()) {
                mapping.push_back({ kLetters[i], kVariants[v] });
            }
        }
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

    const muse::TranslatableString actionName = !mapping.empty()
                                                ? muse::TranslatableString("undoableAction", "Apply Persian key signature")
                                                : muse::TranslatableString("undoableAction", "Clear Persian key signature");

    n->undoStack()->transaction(actionName, [&](mu::engraving::Transaction&) {
        // Write the real key signature on the staff AND respell/retune
        // the notes (what you see is what you hear).
        engraving::EditPersianKeySig::applyKeySigToStaves(sc->masterScore(), mapping, centsFor);
    });
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

        if (isCustom) {
            const QString customJson = muse::settings()->value(kPersianKeyCustom).toQString();
            QJsonObject customRoot = QJsonDocument::fromJson(customJson.toUtf8()).object();
            QJsonObject entry;
            for (int i = 0; i < (int)kLetters.size(); ++i) {
                const int v = customMapping.value(QString::fromStdString(kLetters[i]), 0).toInt();
                if (v > 0) {
                    entry.insert(QString::fromStdString(kLetters[i]), v);
                }
            }
            customRoot.insert(scoreId, entry);
            muse::settings()->setSharedValue(kPersianKeyCustom,
                                             muse::Val(QString::fromUtf8(QJsonDocument(customRoot).toJson(QJsonDocument::Compact))));
        }
    }

    refreshPersianKey();
}
