#include <openpose/wrapper/wrapperStructFace.hpp>

namespace op
{
    WrapperStructFace::WrapperStructFace(const bool enable_, const Point<int>& netInputSize_, const RenderMode renderMode_,
                                         const float alphaKeypoint_, const float alphaHeatMap_,
                                         const float renderThreshold_, const int faceDetector_) :
        enable{enable_},
        netInputSize{netInputSize_},
        renderMode{renderMode_},
        alphaKeypoint{alphaKeypoint_},
        alphaHeatMap{alphaHeatMap_},
        renderThreshold{renderThreshold_},
        faceDetector{faceDetector_}
    {
    }
}
