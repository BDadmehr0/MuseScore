#pragma once
#include <array>

namespace mu::engraving {

class TuningSystem {
    public:

        TuningSystem();

        double centOffset(int midiPitch) const;

    private:

        std::array<double,12> m_offsets;
    };
}