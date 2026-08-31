/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Controller of the "accidentals" symbols row in the notation toolbar.
 */

#include "accidentalsymbolsbarcontroller.h"

#include "notation/inotation.h"

#include "log.h"

using namespace mu::notation;
using namespace muse;

static const QMap<QString, actions::ActionCode> kVariantAction {
    { "flat", "notation/add-flat" },
    { "natural", "notation/add-natural" },
    { "koron", "notation/add-koron" },
    { "sori", "notation/add-sori" },
    { "sharp", "notation/add-sharp" },
};

AccidentalSymbolsBarController::AccidentalSymbolsBarController(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
}

void AccidentalSymbolsBarController::init()
{
    onCurrentNotationChanged();
    globalContext()->currentNotationChanged().onNotify(this, [this]() {
        onCurrentNotationChanged();
    });
}

void AccidentalSymbolsBarController::onCurrentNotationChanged()
{
    refreshSelectionState();

    INotationPtr n = globalContext()->currentNotation();
    if (!n || !n->interaction()) {
        return;
    }
    n->interaction()->selectionChanged().onNotify(this, [this]() {
        refreshSelectionState();
    }, Asyncable::Mode::SetReplace);
}

void AccidentalSymbolsBarController::refreshSelectionState()
{
    const bool hasNote = commandsController() && commandsController()->isNoteOrRestSelected();
    if (m_hasNoteSelection != hasNote) {
        m_hasNoteSelection = hasNote;
        emit stateChanged();
    }
}

void AccidentalSymbolsBarController::applyAccidental(const QString& variant)
{
    const auto it = kVariantAction.constFind(variant);
    if (it == kVariantAction.cend()) {
        LOGW() << "AccidentalSymbolsBar: unknown variant: " << variant;
        return;
    }
    if (!dispatcher()) {
        return;
    }
    dispatcher()->dispatch(it.value());
}
