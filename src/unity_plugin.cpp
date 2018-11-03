#ifdef USE_UNITY_SUPPORT
// ------------------------- OpenPose Unity Binding -------------------------

// OpenPose dependencies
#include <openpose/headers.hpp>

// Output callback register in Unity
typedef void(__stdcall * OutputCallback) (uchar ** ptrs, int ptrSize, int * sizes, int sizeSize, uchar outputType);

// Global output callback
OutputCallback unityOutputCallback;
bool unityOutputEnabled = true;

// This worker will just read and return all the jpg files in a directory
class UnityPluginUserOutput : public op::WorkerConsumer<std::shared_ptr<std::vector<op::Datum>>> {
public:	
	void initializationOnThread() {}

	enum class OutputType : uchar {
		None,
		DatumsInfo,
		Name,
		PoseKeypoints,
		PoseIds,
		PoseScores,
		PoseHeatMaps,
		PoseCandidates,
		FaceRectangles,
		FaceKeypoints,
		FaceHeatMaps,
		HandRectangles,
		HandKeypoints,
		HandHeightMaps,
		PoseKeypoints3D,
		FaceKeypoints3D,
		HandKeypoints3D,
		CameraMatrix,
		CameraExtrinsics,
		CameraIntrinsics
	};

protected:
	void workConsumer(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		try	{
			if (datumsPtr != nullptr && !datumsPtr->empty()) {				
				/*if (unityOutputEnabled) {
					sendDatumsInfoAndName(datumsPtr);
					sendPoseKeypoints(datumsPtr);
					sendPoseIds(datumsPtr);
					sendPoseScores(datumsPtr);
					sendPoseHeatMaps(datumsPtr);
					sendPoseCandidates(datumsPtr);
					sendFaceRectangles(datumsPtr);
					sendFaceKeypoints(datumsPtr);
					sendFaceHeatMaps(datumsPtr);
					sendHandRectangles(datumsPtr);
					sendHandKeypoints(datumsPtr);
					sendHandHeatMaps(datumsPtr);
				}*/
			}
		} catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}

private: 
	template<class T>
	void outputValue(T ** ptrs, int ptrSize, int * sizes, int sizeSize, OutputType outputType) {
		if (!unityOutputCallback) return;
		uchar ** bytePtrs = static_cast<uchar**>(static_cast<void*>(ptrs));
		unityOutputCallback(bytePtrs, ptrSize, sizes, sizeSize, (uchar)outputType);
	}

	void sendDatumsInfoAndName(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& datum = datumsPtr->at(0);
		int sizes[] = { 1 };
		int sizeSize = 1;
		unsigned long long *val[] = {&(datum.id), &(datum.subId), &(datum.subIdMax), &(datum.frameNumber)};
		int ptrSize = 4;
		outputValue(&val[0], ptrSize, &sizes[0], sizeSize, OutputType::DatumsInfo);

		char const *a[] = { datum.name.c_str() };
		outputValue(&a[0], 1, &sizes[0], sizeSize, OutputType::Name);
	}
	void sendPoseKeypoints(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).poseKeypoints; // Array<float>
		if (!data.empty()) {
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::PoseKeypoints);
		}
	}
	void sendPoseIds(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).poseIds; // Array<long long>
		if (!data.empty()) {
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			long long * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::PoseIds);
		}
	}
	void sendPoseScores(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).poseScores; // Array<float>
		if (!data.empty()) {
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::PoseScores);
		}
	}
	void sendPoseHeatMaps(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).poseHeatMaps; // Array<float>
		if (!data.empty()) {
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::PoseHeatMaps);
		}
	}
	void sendPoseCandidates(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).poseCandidates; // std::vector<std::vector<std::array<float, 3>>>
		if (!data.empty()) {
			// TODO 
			/*auto a = data[0][0].data();
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			long long * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::PoseIds);*/
		}
	}	
	void sendFaceRectangles(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).faceRectangles; // std::vector<Rectangle<float>>
		if (data.size() > 0) {
			int sizes[] = { data.size(), 4 };
			std::vector<float> vals(data.size() * 4);
			for (int i = 0; i < data.size(); i++) {
				vals[4 * i + 0] = data[i].x;
				vals[4 * i + 1] = data[i].y;
				vals[4 * i + 2] = data[i].width;
				vals[4 * i + 3] = data[i].height;
			}
			float * val = &vals[0];
			outputValue(&val, 1, sizes, 2, OutputType::FaceRectangles);
		}
	}
	void sendFaceKeypoints(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).faceKeypoints; // Array<float>
		if (!data.empty()) {
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::FaceKeypoints);
		}
	}
	void sendFaceHeatMaps(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).faceHeatMaps; // Array<float>
		if (!data.empty()) {
			auto sizeVector = data.getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * val = data.getPtr();
			outputValue(&val, 1, sizes, sizeSize, OutputType::FaceHeatMaps);
		}
	}
	void sendHandRectangles(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).handRectangles; // std::vector<std::array<Rectangle<float>, 2>>
		if (!data.empty()) {
			std::vector<float*> valPtrs;
			for (int i = 0; i < data.size(); i++) {
				float vals[8];
				for (int j = 0; j < 2; j++) {
					vals[4 * j + 0] = data[i][j].x;
					vals[4 * j + 1] = data[i][j].y;
					vals[4 * j + 2] = data[i][j].width;
					vals[4 * j + 3] = data[i][j].height;
				}
				valPtrs.push_back(vals);
			}
			int sizes[] = {2, 4};
			int sizeSize = 2;
			outputValue(valPtrs.data(), valPtrs.size(), sizes, sizeSize, OutputType::HandRectangles);
		}
	}
	void sendHandKeypoints(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).handKeypoints; // std::array<Array<float>, 2>
		if (data.size() == 2 && !data[0].empty()) {
			auto sizeVector = data[0].getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * ptrs[] = { data[0].getPtr(), data[1].getPtr() };
			outputValue(ptrs, 2, sizes, sizeSize, OutputType::HandKeypoints);
		}
	}
	void sendHandHeatMaps(const std::shared_ptr<std::vector<op::Datum>>& datumsPtr) {
		auto& data = datumsPtr->at(0).handHeatMaps; // std::array<Array<float>, 2>
		if (data.size() == 2 && !data[0].empty()) {
			auto sizeVector = data[0].getSize();
			int sizeSize = sizeVector.size();
			int * sizes = &sizeVector[0];
			float * ptrs[] = { data[0].getPtr(), data[1].getPtr() };
			outputValue(ptrs, 2, sizes, sizeSize, OutputType::HandHeightMaps);
		}
	}
};

// Global user output
UnityPluginUserOutput* ptrUserOutput = nullptr;

// Global setting structs
std::shared_ptr<op::WrapperStructPose> spWrapperStructPose;
std::shared_ptr<op::WrapperStructHand> spWrapperStructHand;
std::shared_ptr<op::WrapperStructFace> spWrapperStructFace;
std::shared_ptr<op::WrapperStructExtra> spWrapperStructExtra;
std::shared_ptr<op::WrapperStructInput> spWrapperStructInput;
std::shared_ptr<op::WrapperStructOutput> spWrapperStructOutput;

// Main
void openpose_main() {
	try {
		// Starting
		if (ptrUserOutput) return;
		op::log("Starting OpenPose demo...", op::Priority::High);
		const auto timerBegin = std::chrono::high_resolution_clock::now();

		// OpenPose wrapper
		auto spWrapper = std::make_shared<op::Wrapper>();

		// Initializing the user custom classes
		auto spUserOutput = std::make_shared<UnityPluginUserOutput>();
		ptrUserOutput = spUserOutput.get();
		
		// Add custom processing
		const auto workerOutputOnNewThread = true;
		spWrapper->setWorker(op::WorkerType::Output, spUserOutput, workerOutputOnNewThread);

		// Apply configurations
		spWrapper->configure(*spWrapperStructPose);
		spWrapper->configure(*spWrapperStructHand);
		spWrapper->configure(*spWrapperStructFace);
		spWrapper->configure(*spWrapperStructExtra);
		spWrapper->configure(*spWrapperStructInput);
		spWrapper->configure(*spWrapperStructOutput);

		// Start processing
		op::log("Starting thread(s)...", op::Priority::High);
		spWrapper->exec();

		// Running ...... Ending

		// Measuring total time
		const auto now = std::chrono::high_resolution_clock::now();
		const auto totalTimeSec = (double)std::chrono::duration_cast<std::chrono::nanoseconds>(now - timerBegin).count()
			* 1e-9;
		const auto message = "OpenPose demo successfully finished. Total time: "
			+ std::to_string(totalTimeSec) + " seconds.";
		op::log(message, op::Priority::High);

		// Reset pointer
		ptrUserOutput = nullptr;
	} catch (const std::exception& e) {
		op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
	}
}

// Functions called from Unity
extern "C" {
	// Start openpose safely
	OP_API void OP_Run() {
		if (ptrUserOutput == nullptr) 
			openpose_main();
	}
	// Stop openpose safely
	OP_API void OP_Shutdown() {
		if (ptrUserOutput != nullptr) {
			op::log("Stopping...");
			ptrUserOutput->stop();
		}
	}
	// Register Unity output callback function
	OP_API void OP_RegisterOutputCallback(OutputCallback callback) {
		unityOutputCallback = callback;
	}
	// Enable/disable output callback
	OP_API void OP_SetOutputEnable(bool enable) {
		unityOutputEnabled = enable;
	}
	// Configs
	OP_API void OP_ConfigurePose(
		bool body_disable,
		int net_resolution_x, int net_resolution_y, // Point
		int output_resolution_x, int output_resolution_y, // Point
		uchar keypoint_scale_mode, // ScaleMode
		int num_gpu, int num_gpu_start, int scale_number, float scale_gap,
		uchar pose_render_mode, // RenderMode
		uchar model_pose, // PoseModel
		bool disable_blending, float alpha_pose, float alpha_heatmap, int part_to_show, char* model_folder,
		bool heatmaps_add_parts, bool heatmaps_add_bkg, bool heatmaps_add_PAFs, // HeatMapType // uchar heatmap_type,
		uchar heatmap_scale_mode, // ScaleMode
		bool part_candidates, float render_threshold, int number_people_max) {

		try {
			spWrapperStructPose = std::make_shared<op::WrapperStructPose>(
				!body_disable,
				op::Point<int>{ net_resolution_x, net_resolution_y },
				op::Point<int>{ output_resolution_x, output_resolution_y },
				(op::ScaleMode) keypoint_scale_mode,
				num_gpu, num_gpu_start, scale_number, scale_gap,
				(op::RenderMode) pose_render_mode, (op::PoseModel) model_pose,
				!disable_blending, alpha_pose, alpha_heatmap, part_to_show, model_folder,
				op::flagsToHeatMaps(heatmaps_add_parts, heatmaps_add_bkg, heatmaps_add_PAFs), // HeatMapType // (op::HeatMapType) heatmap_type, 
				(op::ScaleMode) heatmap_scale_mode,
				part_candidates, render_threshold, number_people_max, true
			);
		} catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}
	OP_API void OP_ConfigureHand(
		bool hand,
		int hand_net_resolution_x, int hand_net_resolution_y, // Point
		int hand_scale_number, float hand_scale_range, bool hand_tracking,
		uchar hand_render_mode, // RenderMode
		float hand_alpha_pose, float hand_alpha_heatmap, float hand_render_threshold) {

		try {
			spWrapperStructHand = std::make_shared<op::WrapperStructHand>(
				hand,
				op::Point<int>{ hand_net_resolution_x, hand_net_resolution_y },
				hand_scale_number, hand_scale_range, hand_tracking,
				(op::RenderMode) hand_render_mode,
				hand_alpha_pose, hand_alpha_heatmap, hand_render_threshold
				);
		}
		catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}
	OP_API void OP_ConfigureFace(
		bool face, 
		int face_net_resolution_x, int face_net_resolution_y, // Point
		uchar face_render_mode, // RenderMode
		float face_alpha_pose, float face_alpha_heatmap, float face_render_threshold) {

		try {
			spWrapperStructFace = std::make_shared<op::WrapperStructFace>(
				face, 
				op::Point<int>{ face_net_resolution_x, face_net_resolution_y },
				(op::RenderMode) face_render_mode,
				face_alpha_pose, face_alpha_heatmap, face_render_threshold
			);
		} catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}
	OP_API void OP_ConfigureExtra(
		bool _3d, int _3d_min_views, bool _identification, int _tracking, int _ik_threads) {

		try {
			spWrapperStructExtra = std::make_shared<op::WrapperStructExtra>(
				_3d, _3d_min_views, _identification, _tracking, _ik_threads
			);
		} catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}
	OP_API void OP_ConfigureInput(
		uchar producer_type, char* producer_string, // ProducerType
		unsigned long long frame_first, unsigned long long frame_step, unsigned long long frame_last,
		bool process_real_time, bool frame_flip, int frame_rotate, bool frames_repeat, 
		int camera_resolution_x, int camera_resolution_y, // Point
		double webcam_fps, char* camera_parameter_path, bool undistort_image, uint image_directory_stereo) {

		try {
			spWrapperStructInput = std::make_shared<op::WrapperStructInput>(
				(op::ProducerType) producer_type, producer_string,
				frame_first, frame_step, frame_last, process_real_time, frame_flip,	frame_rotate, frames_repeat,
				op::Point<int>{ camera_resolution_x, camera_resolution_y }, 
				webcam_fps,	camera_parameter_path, undistort_image, image_directory_stereo
			);
		} catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}
	OP_API void OP_ConfigureOutput(
		ushort display_mode, // DisplayMode
		bool gui_verbose, bool full_screen, char* write_keypoint,
		uchar write_keypoint_format, // DataFormat
		char* write_json, char* write_coco_json, char* write_coco_foot_json, 
		char* write_images, char* write_images_format, char* write_video,
		double camera_fps, char* write_heatmaps, char* write_heatmaps_format, 
		char* write_video_adam, char* write_bvh, char* udp_host, char* udp_port) {

		try {
			//const bool guiVerbose = false;
			//const bool fullScreen = false;
			spWrapperStructOutput = std::make_shared<op::WrapperStructOutput>(
				(op::DisplayMode) display_mode, gui_verbose, full_screen, write_keypoint,
				(op::DataFormat) write_keypoint_format, write_json, write_coco_json,
				write_coco_foot_json, write_images, write_images_format, write_video,
				camera_fps, write_heatmaps, write_heatmaps_format, write_video_adam, write_bvh, 
				udp_host, udp_port);
		} catch (const std::exception& e) {
			op::error(e.what(), __LINE__, __FUNCTION__, __FILE__);
		}
	}
}

#endif