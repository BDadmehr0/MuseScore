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
#pragma once

#include <QVariantList>

#include <qqmlintegration.h>

#include "propertiespanelabstractmodel.h"

namespace mu::propertiespanel {
class KeySignatureSettingsModel : public PropertiesPanelAbstractModel
{
    Q_OBJECT
    QML_ELEMENT;
    QML_UNCREATABLE("Not creatable from QML")

    Q_PROPERTY(mu::propertiespanel::PropertyItem * hasToShowCourtesy READ hasToShowCourtesy CONSTANT)
    Q_PROPERTY(mu::propertiespanel::PropertyItem * mode READ mode CONSTANT)

    // Predefined Persian key signatures (charghah / dastgah), applied
    // on top of the Western key.
    Q_PROPERTY(QVariantList persianKeyPatterns READ persianKeyPatterns CONSTANT)
    Q_PROPERTY(int persianKeyPatternIndex READ persianKeyPatternIndex NOTIFY persianKeyPatternIndexChanged)
    Q_PROPERTY(QString persianKeyPatternDescription READ persianKeyPatternDescription NOTIFY persianKeyPatternIndexChanged)
    Q_PROPERTY(bool hasPersianKey READ hasPersianKey NOTIFY persianKeyPatternIndexChanged)

    // Custom Persian key: one variant per note letter
    // (Do Re Mi Fa Sol La Si / C D E F G A B). The whole key is built
    // from these seven rows, so any flat/koron/sori/sharp combination
    // is possible.
    Q_PROPERTY(QVariantList letterNames READ letterNames CONSTANT)
    Q_PROPERTY(QVariantList variantNames READ variantNames CONSTANT)
    Q_PROPERTY(QVariantList customVariants READ customVariants NOTIFY customVariantsChanged)
    Q_PROPERTY(bool isCustomPersianKey READ isCustomPersianKey NOTIFY persianKeyPatternIndexChanged)
public:
    explicit KeySignatureSettingsModel(QObject* parent, const muse::modularity::ContextPtr& iocCtx, IElementRepositoryService* repository);

    void createProperties() override;
    void requestElements() override;
    void loadProperties() override;

    PropertyItem* hasToShowCourtesy() const;
    PropertyItem* mode() const;

    QVariantList persianKeyPatterns() const;
    int persianKeyPatternIndex() const;
    QString persianKeyPatternDescription() const;
    bool hasPersianKey() const;

    QVariantList letterNames() const;
    QVariantList variantNames() const;
    QVariantList customVariants() const;
    bool isCustomPersianKey() const;

    Q_INVOKABLE void setPersianKeyPatternIndex(int index);
    Q_INVOKABLE void applyPersianKey();
    Q_INVOKABLE void clearPersianKey();

    //! Set the accidental variant (0 = natural, 1 = flat, 2 = koron,
    //! 3 = sori, 4 = sharp) of letter \p letterIndex (0 = Do/C ... 6 = Si/B)
    //! and apply the resulting custom key to the score.
    Q_INVOKABLE void setCustomVariant(int letterIndex, int variantIndex);
    Q_INVOKABLE void resetCustomKey();

signals:
    void persianKeyPatternIndexChanged();
    void customVariantsChanged();

private:
    void refreshPersianKey();
    QString persianKeyPatternId() const;
    void applyPersianKeyPattern(const QString& patternId, const QVariantMap& customMapping = QVariantMap());
    void setCustomVariantsFromPattern(const QString& patternId, const QVariantMap& customMapping);
    QVariantMap storedCustomMapping() const;

    PropertyItem* m_hasToShowCourtesy = nullptr;
    PropertyItem* m_mode = nullptr;
    QString m_persianKeyPatternId;
    QVariantList m_customVariants; // index into variantNames per letter
};
}
