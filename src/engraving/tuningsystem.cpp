#include "tuningsystem.h"

using namespace mu::engraving;

TuningSystem::TuningSystem()
{
    // Equal temperament

    m_offsets[0]=0;      // C
    m_offsets[1]=0;      // C#
    m_offsets[2]=0;      // D
    m_offsets[3]=-50;    // D half-flat (کرن)
    m_offsets[4]=0;      // E
    m_offsets[5]=0;      // F
    m_offsets[6]=0;      // F#
    m_offsets[7]=0;      // G
    m_offsets[8]=-50;    // A half-flat
    m_offsets[9]=0;      // A
    m_offsets[10]=0;     // Bb
    m_offsets[11]=0;     // B
}

double TuningSystem::centOffset(int midiPitch) const
{
    return m_offsets[midiPitch % 12];
}