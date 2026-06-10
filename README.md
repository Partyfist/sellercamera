# Seller Camera

Seller Camera 是面向电商与销售场景的商品图采集与标准化拍摄 App。

## 当前正式主线状态（R27）

- 当前正式开发基线：`main@d6b013d6cf4821edb67c965f221c42fbd2203b2c`
- 端侧正式分割/白底主线：`Vision`（`VNGenerateForegroundInstanceMaskRequest`）
- 多模型实验能力：已从正式主线收口，不作为当前正式产品能力暴露

## 实验分支归档

- 历史多模型实验冻结分支：`archive/experiment-multimodel-r25-20260424`
- 用途：保留 Tiny / RMBG-2 / admission/runtime/terminal 相关实验链，不用于当前正式主线开发

## 文档索引

- 主线收口说明：`docs/mainline_vision_scope.md`
- R27 正式清理报告：`docs/reports/r27_mainline_vision_convergence_cleanup.md`
- R28 EV/WB 真机验证闭环报告：`docs/reports/r28_ev_wb_device_validation_closure.md`
- R29 EV/WB/ISO 真机验证闭环报告：`docs/reports/r29_ev_wb_iso_device_validation_closure.md`
- R30 Shutter 滚轮接入报告：`docs/reports/r30_shutter_wheel_write_integration.md`
- R31 EV/WB/ISO/Shutter 真机验证闭环报告：`docs/reports/r31_ev_wb_iso_shutter_device_validation_closure.md`
- R32 Focus 前置方案报告：`docs/reports/r32_focus_semantics_and_manual_focus_preflight.md`
- R33 Focus 滚轮接入报告：`docs/reports/r33_focus_wheel_manual_auto_integration.md`
- R34 五参数综合真机验证闭环报告：`docs/reports/r34_five_parameter_device_validation_and_polish.md`
- R35 五参数人工真机闭环补验报告：`docs/reports/r35_five_parameter_manual_device_validation_followup.md`
- R36 Focus 移出五参数栏 + TINT 骨架接入报告：`docs/reports/r36_focus_removed_tint_scaffold.md`
- R37 TINT 色偏真实写入 / White Balance Tint 接入报告：`docs/reports/r37_tint_white_balance_tint_integration.md`
- R38 TINT 合同修正为 RESET + WB/TINT 真机色彩验证报告：`docs/reports/r38_tint_reset_contract_and_wb_tint_validation.md`
- R39 五参数真机综合验证 + 参数精度与状态打磨报告：`docs/reports/r39_five_parameter_device_validation_precision_and_state_polish.md`
- R40 拍摄页专业控制台视觉质感 + 动效手感打磨报告：`docs/reports/r40_capture_control_console_visual_motion_polish.md`
- R41 五参数滚轮阻尼与常用区精度修正报告：`docs/reports/r41_five_parameter_dial_damping_and_precision_tuning.md`
- R42 五参数滚轮精密阻尼二次收口报告：`docs/reports/r42_five_parameter_precision_dial_damping_closure.md`
- R43 五参数档位精细化二次收口报告：`docs/reports/r43_five_parameter_tick_precision_refinement.md`
- 飓风相机拍摄页 UI/UX 调研报告：`docs/reports/hurricane_camera_ui_ux_research.md`
- R44 Seller Camera 原创控制台与横向刻度尺报告：`docs/reports/r44_seller_camera_original_control_console_and_horizontal_ruler.md`
- R45 拍摄页取景主体优先布局收口报告：`docs/reports/r45_capture_layout_viewfinder_first_control_console_reflow.md`
- R46 底部操作层覆盖式重构与镜头调节接入报告：`docs/reports/r46_bottom_action_overlay_and_lens_ruler_control.md`
- R47 底部控制台视觉统一收口报告：`docs/reports/r47_control_console_visual_unification_and_bottom_action_lowering.md`
- R48 拍摄页参数控制台代码清理收口报告：`docs/reports/r48_capture_console_code_cleanup_and_dead_code_removal.md`
- R49 独立 Focus 对焦系统 UI 方案与接入前置报告：`docs/reports/r49_independent_focus_system_preflight.md`
- R49 五参数贴合式刻度交互与 TINT 修复报告：`docs/reports/r49_parameter_inline_ruler_interaction_and_tint_fix.md`
- R50 五参数贴合式刻度层真机修正报告：`docs/reports/r50_inline_ruler_dismiss_animation_and_tick_alignment.md`
- R51 镜头焦段调节 UI 同步与重叠修复报告：`docs/reports/r51_lens_ruler_zoom_ui_sync_and_overlap_fix.md`
- R52 取景区视觉噪音与镜头刻度精简报告：`docs/reports/r52_viewfinder_visual_noise_and_lens_ruler_simplification.md`
- R53 Shutter 调参后交互卡顿修复与最小性能体检报告：`docs/reports/r53_capture_console_shutter_stall_fix_minimal_audit.md`
- R54 右上角更多面板内部操作保持打开与外部点击关闭报告：`docs/reports/r54_more_panel_persistent_interaction_and_outside_dismiss.md`
- R55 独立 Focus 对焦系统 UI 方案与接入前置报告：`docs/reports/r55_independent_focus_system_preflight.md`
- R56 独立 Focus 状态胶囊 + AF / MF / LOCK 最小 UI 骨架报告：`docs/reports/r56_independent_focus_status_capsule_and_panel_skeleton.md`
- R57 Focus 面板交互语义与 MF 微调前置报告：`docs/reports/r57_focus_panel_interaction_semantics_and_mf_preflight.md`
- R58 Focus 控制组 AE-L / MF 焦段两侧重构报告：`docs/reports/r58_focus_control_group_ael_mf_lens_strip_relayout.md`
- R59 Manual Focus 低位微调 ruler + lensPosition 写入闭环报告：`docs/reports/r59_manual_focus_ruler_lens_position_write_closure.md`
- R60 Focus 真机闭环收口 + MF 手感微调 + 状态表达清理报告：`docs/reports/r60_focus_device_closure_mf_feel_and_state_cleanup.md`
- R61 参数横向滚轮边界残留修复 + Drag Consumption 收口报告：`docs/reports/r61_parameter_drag_boundary_consumption_closure.md`
- R62 AUTO → MANUAL 参数接管收口报告：`docs/reports/r62_auto_to_manual_parameter_takeover_closure.md`
- R63 Xcode/模拟器 WB AUTO 首滑诊断与接管修复报告：`docs/reports/r63_xcode_simulator_wb_auto_takeover_diagnosis.md`
- R64 全代码状态体检 + 参数系统精简收口报告：`docs/reports/r64_full_code_state_audit_parameter_simplification.md`
- R66 拍摄页顶部对齐与焦段控制区间距优化报告：`docs/reports/r66_capture_ui_alignment_lens_control_spacing.md`
- R66 ISO / Shutter 自定义曝光写入安全夹取报告：`docs/reports/r66_exposure_iso_shutter_write_safety_clamp.md`
- R67 ISO / Shutter / EV 曝光三角联动关系收口报告：`docs/reports/r67_exposure_triangle_iso_shutter_ev_linkage.md`
- R68 曝光三角半自动模式收口报告：`docs/reports/r68_exposure_triangle_semiauto_linkage_closure.md`
- R69 Shutter 全范围能力映射收口报告：`docs/reports/r69_shutter_full_range_mapping_closure.md`
- R70 Shutter ruler 交互映射与常用快门锚点修复报告：`docs/reports/r70_shutter_ruler_interaction_mapping_fix.md`
- R71A Shutter ruler 双向拖拽与惯性修复报告：`docs/reports/r71a_shutter_ruler_bidirectional_inertia_fix.md`
- R73 参数表盘真机体验验收与收口修复报告：`docs/reports/r73_parameter_ruler_real_device_acceptance_and_closure.md`
- R73A 参数表盘拖动灵敏度加速修复报告：`docs/reports/r73a_parameter_ruler_drag_sensitivity_acceleration.md`
- R73B 参数表盘惯性统一与 MF 精细化收口报告：`docs/reports/r73b_parameter_ruler_inertia_and_mf_density_closure.md`
- R73C MF Ruler 重复数值显示清理报告：`docs/reports/r73c_mf_ruler_duplicate_value_cleanup.md`
- R73D MF Ruler 重复显示真因定位与最小修复报告：`docs/reports/r73d_mf_ruler_duplicate_display_root_cause.md`
- R73E MF Ruler 刻度间距减半与拖动覆盖增强报告：`docs/reports/r73e_mf_ruler_tick_spacing_halved_and_drag_range.md`
- R74 商品 Auto 实时曝光优化 1.0 报告：`docs/reports/r74_product_auto_realtime_exposure_optimization.md`
- R74A 商品 Auto EV 真机验收与阈值收口报告：`docs/reports/r74a_product_auto_ev_real_device_acceptance.md`
- R74B 商品 Auto EV 场景阈值校准报告：`docs/reports/r74b_product_auto_ev_scene_threshold_calibration.md`
- R75 商品 Auto WB 实时白平衡优化 1.0 报告：`docs/reports/r75_product_auto_wb_realtime_white_balance.md`
- R75A 商品 Auto WB 真机场景校准报告：`docs/reports/r75a_product_auto_wb_real_device_calibration.md`
- R75B 商品 Auto EV + WB 联合真机样本验收报告：`docs/reports/r75b_product_auto_ev_wb_joint_acceptance.md`
- R75C 商品 Auto 固定样本验收与日志采集规范报告：`docs/reports/r75c_product_auto_fixed_sample_acceptance_protocol.md`
- R76 商品清晰度检测与对焦辅助 1.0 报告：`docs/reports/r76_product_sharpness_detection_focus_assist.md`
- R76A 商品清晰度检测真机样本校准报告：`docs/reports/r76a_product_sharpness_real_device_calibration.md`
- R76B 商品清晰度检测固定样本验收报告：`docs/reports/r76b_product_sharpness_fixed_sample_acceptance.md`
- R76C S / MF 参数表盘手感回归修复报告：`docs/reports/r76c_shutter_mf_ruler_feel_regression_fix.md`
- R76D MF Ruler 拖动速度二次加速报告：`docs/reports/r76d_mf_ruler_drag_speed_boost.md`
- R76E MF Ruler 拖动速度三次加速报告：`docs/reports/r76e_mf_ruler_drag_speed_double_boost.md`
- R76F MF 同距参数覆盖范围修复报告：`docs/reports/r76f_mf_ruler_same_distance_range_fix.md`
- R76G MF Ruler 真机手感稳定性收口报告：`docs/reports/r76g_mf_ruler_stability_closure.md`
- R77 拍照基础体验收口报告：`docs/reports/r77_camera_capture_foundation_closure.md`
