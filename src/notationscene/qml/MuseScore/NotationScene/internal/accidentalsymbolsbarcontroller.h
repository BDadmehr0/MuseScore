/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Controller of the "accidentals" symbols row in the notation toolbar:
 * the four Western accidentals (flat, natural, sharp + double forms are
 * available through the commands) and the two Persian quarter-tone
 * accidentals (koron / sori). Clicking a symbol assigns it to the
 * selected note - the same actions the top "Notation" symbols row uses.
 */

#pragma once

#include <QObject>
#include <qqmlintegration.h>

#include "async/asyncable.h"
#include "modularity/ioc.h"

#include "actions/iactionsdispatcher.h"
#include "context/iglobalcontext.h"

#include "notationscene/inotationcommandscontroller.h"

namespace mu::notation {
class AccidentalSymbolsBarController : public QObject, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(bool hasNoteSelection READ hasNoteSelection NOTIFY stateChanged)

    QML_ELEMENT

    muse::ContextInject<mu::context::IGlobalContext> globalContext = { this };
    muse::ContextInject<muse::actions::IActionsDispatcher> dispatcher = { this };
    muse::ContextInject<INotationCommandsController> commandsController = { this };

public:
    explicit AccidentalSymbolsBarController(QObject* parent = nullptr);

    bool hasNoteSelection() const { return m_hasNoteSelection; }

    //! Assign \a variant ("flat", "natural", "koron", "sori", "sharp")
    //! to the selected note(s).
    Q_INVOKABLE void applyAccidental(const QString& variant);

    Q_INVOKABLE void init();

signals:
    void stateChanged();

private:
    void onCurrentNotationChanged();
    void refreshSelectionState();

    bool m_hasNoteSelection = false;
};
}
