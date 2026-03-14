-- REQ-30: Large seed for muscles, exercises, and exercise-muscle mapping.
-- Includes 250 exercises across free weight, machine, bodyweight, cable,
-- band, kettlebell, olympic, strongman, cardio, and plyometric categories.

begin;

-- -----------------------------------------------------------------------------
-- 1) Muscles (frontend SVG path IDs)
-- -----------------------------------------------------------------------------
insert into public.muscles (code, display_name, display_order)
values
  ('chest', 'Chest', 10),
  ('upper_chest', 'Upper Chest', 20),
  ('serratus_anterior', 'Serratus Anterior', 30),
  ('front_deltoid', 'Front Deltoid', 40),
  ('lateral_deltoid', 'Lateral Deltoid', 50),
  ('rear_deltoid', 'Rear Deltoid', 60),
  ('upper_trapezius', 'Upper Trapezius', 70),
  ('middle_trapezius', 'Middle Trapezius', 80),
  ('lower_trapezius', 'Lower Trapezius', 90),
  ('lats', 'Latissimus Dorsi', 100),
  ('rhomboids', 'Rhomboids', 110),
  ('spinal_erectors', 'Spinal Erectors', 120),
  ('biceps', 'Biceps', 130),
  ('triceps', 'Triceps', 140),
  ('forearm_flexors', 'Forearm Flexors', 150),
  ('forearm_extensors', 'Forearm Extensors', 160),
  ('transverse_abdominis', 'Transverse Abdominis', 170),
  ('abs', 'Rectus Abdominis', 180),
  ('obliques', 'Obliques', 190),
  ('hip_flexors', 'Hip Flexors', 200),
  ('glutes', 'Glutes', 210),
  ('abductors', 'Hip Abductors', 220),
  ('adductors', 'Hip Adductors', 230),
  ('quadriceps', 'Quadriceps', 240),
  ('hamstrings', 'Hamstrings', 250),
  ('calves', 'Calves', 260),
  ('tibialis_anterior', 'Tibialis Anterior', 270)
on conflict (code) do update
set
  display_name = excluded.display_name,
  display_order = excluded.display_order,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 2) Group-level muscle mapping + 250 exercise seeds
-- -----------------------------------------------------------------------------
with exercise_group_seed as (
  select *
  from (
    values
      ('chest_press', 'chest', array['front_deltoid', 'triceps', 'serratus_anterior']::text[]),
      ('chest_fly', 'chest', array['front_deltoid', 'serratus_anterior']::text[]),
      ('push_up', 'chest', array['front_deltoid', 'triceps', 'abs']::text[]),
      ('chest_dip', 'chest', array['triceps', 'front_deltoid']::text[]),
      ('deadlift_pattern', 'hamstrings', array['glutes', 'spinal_erectors', 'lats']::text[]),
      ('row_pattern', 'lats', array['rhomboids', 'rear_deltoid', 'biceps', 'middle_trapezius']::text[]),
      ('pull_pattern', 'lats', array['biceps', 'rear_deltoid', 'lower_trapezius', 'forearm_flexors']::text[]),
      ('upper_back_isolation', 'middle_trapezius', array['rear_deltoid', 'rhomboids', 'lower_trapezius']::text[]),
      ('overhead_press', 'front_deltoid', array['lateral_deltoid', 'triceps', 'upper_chest']::text[]),
      ('lateral_raise', 'lateral_deltoid', array['upper_trapezius']::text[]),
      ('front_raise', 'front_deltoid', array['upper_chest']::text[]),
      ('rear_delt', 'rear_deltoid', array['rhomboids', 'middle_trapezius']::text[]),
      ('upright_pull', 'upper_trapezius', array['lateral_deltoid', 'front_deltoid']::text[]),
      ('biceps_curl', 'biceps', array['forearm_flexors']::text[]),
      ('biceps_hammer', 'biceps', array['forearm_flexors', 'forearm_extensors']::text[]),
      ('triceps_press', 'triceps', array['chest', 'front_deltoid']::text[]),
      ('triceps_extension', 'triceps', array['front_deltoid']::text[]),
      ('forearm_grip', 'forearm_flexors', array['forearm_extensors', 'upper_trapezius']::text[]),
      ('abs_flexion', 'abs', array['hip_flexors']::text[]),
      ('oblique_rotation', 'obliques', array['abs']::text[]),
      ('core_stability', 'transverse_abdominis', array['abs', 'obliques', 'spinal_erectors']::text[]),
      ('posterior_extension', 'spinal_erectors', array['glutes', 'hamstrings']::text[]),
      ('squat_pattern', 'quadriceps', array['glutes', 'adductors', 'hamstrings', 'spinal_erectors']::text[]),
      ('single_leg_pattern', 'quadriceps', array['glutes', 'adductors', 'abductors', 'hamstrings']::text[]),
      ('lunge_pattern', 'quadriceps', array['glutes', 'hamstrings', 'adductors']::text[]),
      ('leg_press_pattern', 'quadriceps', array['glutes', 'hamstrings']::text[]),
      ('leg_extension_pattern', 'quadriceps', array[]::text[]),
      ('hamstring_curl_pattern', 'hamstrings', array['calves']::text[]),
      ('hip_hinge_pattern', 'hamstrings', array['glutes', 'spinal_erectors']::text[]),
      ('hip_thrust_pattern', 'glutes', array['hamstrings', 'spinal_erectors']::text[]),
      ('abduction_pattern', 'abductors', array['glutes']::text[]),
      ('adduction_pattern', 'adductors', array['quadriceps']::text[]),
      ('calf_pattern', 'calves', array['hamstrings']::text[]),
      ('tibialis_pattern', 'tibialis_anterior', array['calves']::text[]),
      ('sled_pattern', 'quadriceps', array['glutes', 'calves', 'hamstrings']::text[]),
      ('plyometric_lower', 'quadriceps', array['calves', 'glutes', 'hamstrings']::text[]),
      ('olympic_pull', 'quadriceps', array['glutes', 'upper_trapezius', 'hamstrings']::text[]),
      ('olympic_lift', 'quadriceps', array['glutes', 'upper_trapezius', 'front_deltoid', 'hamstrings']::text[]),
      ('full_body_power', 'quadriceps', array['glutes', 'chest', 'front_deltoid', 'triceps']::text[]),
      ('kettlebell_ballistic', 'glutes', array['hamstrings', 'spinal_erectors', 'front_deltoid']::text[]),
      ('conditioning_upper', 'front_deltoid', array['lats', 'abs', 'obliques']::text[]),
      ('conditioning_cardio', 'quadriceps', array['calves', 'glutes', 'hamstrings']::text[]),
      ('burpee_pattern', 'quadriceps', array['chest', 'front_deltoid', 'triceps', 'abs']::text[]),
      ('crawl_pattern', 'abs', array['front_deltoid', 'quadriceps', 'glutes']::text[]),
      ('carry_pattern', 'forearm_flexors', array['upper_trapezius', 'abs', 'obliques']::text[]),
      ('climb_pattern', 'lats', array['biceps', 'forearm_flexors', 'abs']::text[]),
      ('strongman_load', 'glutes', array['hamstrings', 'spinal_erectors', 'forearm_flexors', 'upper_trapezius']::text[]),
      ('rotational_throw', 'obliques', array['abs', 'front_deltoid', 'chest']::text[])
  ) as t(group_code, primary_muscle_code, secondary_muscle_codes)
),
exercise_seed as (
  select *
  from (
    values
      ('barbell_flat_bench_press', 'Barbell Flat Bench Press', 'free_weight', 'barbell', 'chest_press'),
      ('barbell_incline_bench_press', 'Barbell Incline Bench Press', 'free_weight', 'barbell', 'chest_press'),
      ('barbell_decline_bench_press', 'Barbell Decline Bench Press', 'free_weight', 'barbell', 'chest_press'),
      ('dumbbell_flat_bench_press', 'Dumbbell Flat Bench Press', 'free_weight', 'dumbbell', 'chest_press'),
      ('dumbbell_incline_bench_press', 'Dumbbell Incline Bench Press', 'free_weight', 'dumbbell', 'chest_press'),
      ('dumbbell_decline_bench_press', 'Dumbbell Decline Bench Press', 'free_weight', 'dumbbell', 'chest_press'),
      ('smith_machine_flat_bench_press', 'Smith Machine Flat Bench Press', 'machine', 'smith_machine', 'chest_press'),
      ('smith_machine_incline_bench_press', 'Smith Machine Incline Bench Press', 'machine', 'smith_machine', 'chest_press'),
      ('machine_chest_press', 'Machine Chest Press', 'machine', 'chest_press_machine', 'chest_press'),
      ('incline_machine_chest_press', 'Incline Machine Chest Press', 'machine', 'chest_press_machine', 'chest_press'),
      ('decline_machine_chest_press', 'Decline Machine Chest Press', 'machine', 'chest_press_machine', 'chest_press'),
      ('plate_loaded_chest_press', 'Plate Loaded Chest Press', 'machine', 'plate_loaded', 'chest_press'),
      ('seated_cable_chest_press', 'Seated Cable Chest Press', 'cable', 'cable', 'chest_press'),
      ('standing_cable_chest_press', 'Standing Cable Chest Press', 'cable', 'cable', 'chest_press'),
      ('low_to_high_cable_fly', 'Low To High Cable Fly', 'cable', 'cable', 'chest_fly'),
      ('high_to_low_cable_fly', 'High To Low Cable Fly', 'cable', 'cable', 'chest_fly'),
      ('cable_crossover', 'Cable Crossover', 'cable', 'cable', 'chest_fly'),
      ('pec_deck_fly', 'Pec Deck Fly', 'machine', 'pec_deck', 'chest_fly'),
      ('dumbbell_fly', 'Dumbbell Fly', 'free_weight', 'dumbbell', 'chest_fly'),
      ('incline_dumbbell_fly', 'Incline Dumbbell Fly', 'free_weight', 'dumbbell', 'chest_fly'),
      ('decline_dumbbell_fly', 'Decline Dumbbell Fly', 'free_weight', 'dumbbell', 'chest_fly'),
      ('weighted_push_up', 'Weighted Push Up', 'bodyweight', 'weighted_vest', 'push_up'),
      ('standard_push_up', 'Standard Push Up', 'bodyweight', 'bodyweight', 'push_up'),
      ('deficit_push_up', 'Deficit Push Up', 'bodyweight', 'bodyweight', 'push_up'),
      ('ring_push_up', 'Ring Push Up', 'bodyweight', 'gym_rings', 'push_up'),
      ('close_grip_push_up', 'Close Grip Push Up', 'bodyweight', 'bodyweight', 'push_up'),
      ('chest_dip', 'Chest Dip', 'bodyweight', 'dip_bars', 'chest_dip'),
      ('weighted_chest_dip', 'Weighted Chest Dip', 'bodyweight', 'weighted_belt', 'chest_dip'),
      ('guillotine_press', 'Guillotine Press', 'free_weight', 'barbell', 'chest_press'),
      ('squeeze_press', 'Squeeze Press', 'free_weight', 'dumbbell', 'chest_press'),

      ('conventional_deadlift', 'Conventional Deadlift', 'free_weight', 'barbell', 'deadlift_pattern'),
      ('sumo_deadlift', 'Sumo Deadlift', 'free_weight', 'barbell', 'deadlift_pattern'),
      ('romanian_deadlift', 'Romanian Deadlift', 'free_weight', 'barbell', 'hip_hinge_pattern'),
      ('snatch_grip_deadlift', 'Snatch Grip Deadlift', 'free_weight', 'barbell', 'deadlift_pattern'),
      ('rack_pull', 'Rack Pull', 'free_weight', 'barbell', 'deadlift_pattern'),
      ('barbell_bent_over_row', 'Barbell Bent Over Row', 'free_weight', 'barbell', 'row_pattern'),
      ('pendlay_row', 'Pendlay Row', 'free_weight', 'barbell', 'row_pattern'),
      ('t_bar_row', 'T Bar Row', 'free_weight', 't_bar', 'row_pattern'),
      ('chest_supported_t_bar_row', 'Chest Supported T Bar Row', 'machine', 't_bar', 'row_pattern'),
      ('dumbbell_single_arm_row', 'Dumbbell Single Arm Row', 'free_weight', 'dumbbell', 'row_pattern'),
      ('dumbbell_chest_supported_row', 'Dumbbell Chest Supported Row', 'free_weight', 'dumbbell', 'row_pattern'),
      ('seated_cable_row', 'Seated Cable Row', 'cable', 'cable', 'row_pattern'),
      ('wide_grip_seated_cable_row', 'Wide Grip Seated Cable Row', 'cable', 'cable', 'row_pattern'),
      ('close_grip_seated_cable_row', 'Close Grip Seated Cable Row', 'cable', 'cable', 'row_pattern'),
      ('machine_row', 'Machine Row', 'machine', 'row_machine', 'row_pattern'),
      ('hammer_strength_row', 'Hammer Strength Row', 'machine', 'plate_loaded', 'row_pattern'),
      ('landmine_row', 'Landmine Row', 'free_weight', 'landmine', 'row_pattern'),
      ('inverted_row', 'Inverted Row', 'bodyweight', 'bodyweight', 'row_pattern'),
      ('weighted_pull_up', 'Weighted Pull Up', 'bodyweight', 'weighted_belt', 'pull_pattern'),
      ('pull_up', 'Pull Up', 'bodyweight', 'pullup_bar', 'pull_pattern'),
      ('chin_up', 'Chin Up', 'bodyweight', 'pullup_bar', 'pull_pattern'),
      ('neutral_grip_pull_up', 'Neutral Grip Pull Up', 'bodyweight', 'pullup_bar', 'pull_pattern'),
      ('wide_grip_pull_up', 'Wide Grip Pull Up', 'bodyweight', 'pullup_bar', 'pull_pattern'),
      ('lat_pulldown', 'Lat Pulldown', 'machine', 'cable_machine', 'pull_pattern'),
      ('wide_grip_lat_pulldown', 'Wide Grip Lat Pulldown', 'machine', 'cable_machine', 'pull_pattern'),
      ('close_grip_lat_pulldown', 'Close Grip Lat Pulldown', 'machine', 'cable_machine', 'pull_pattern'),
      ('reverse_grip_lat_pulldown', 'Reverse Grip Lat Pulldown', 'machine', 'cable_machine', 'pull_pattern'),
      ('straight_arm_pulldown', 'Straight Arm Pulldown', 'cable', 'cable', 'pull_pattern'),
      ('kneeling_single_arm_pulldown', 'Kneeling Single Arm Pulldown', 'cable', 'cable', 'pull_pattern'),
      ('meadows_row', 'Meadows Row', 'free_weight', 'landmine', 'row_pattern'),
      ('seal_row', 'Seal Row', 'free_weight', 'barbell', 'row_pattern'),
      ('prone_y_raise', 'Prone Y Raise', 'free_weight', 'dumbbell', 'upper_back_isolation'),
      ('face_pull', 'Face Pull', 'cable', 'cable', 'upper_back_isolation'),
      ('rear_delt_cable_row', 'Rear Delt Cable Row', 'cable', 'cable', 'upper_back_isolation'),
      ('scapular_pull_up', 'Scapular Pull Up', 'bodyweight', 'pullup_bar', 'upper_back_isolation'),

      ('standing_barbell_overhead_press', 'Standing Barbell Overhead Press', 'free_weight', 'barbell', 'overhead_press'),
      ('seated_barbell_overhead_press', 'Seated Barbell Overhead Press', 'free_weight', 'barbell', 'overhead_press'),
      ('standing_dumbbell_overhead_press', 'Standing Dumbbell Overhead Press', 'free_weight', 'dumbbell', 'overhead_press'),
      ('seated_dumbbell_overhead_press', 'Seated Dumbbell Overhead Press', 'free_weight', 'dumbbell', 'overhead_press'),
      ('arnold_press', 'Arnold Press', 'free_weight', 'dumbbell', 'overhead_press'),
      ('push_press', 'Push Press', 'free_weight', 'barbell', 'overhead_press'),
      ('machine_shoulder_press', 'Machine Shoulder Press', 'machine', 'shoulder_press_machine', 'overhead_press'),
      ('smith_machine_shoulder_press', 'Smith Machine Shoulder Press', 'machine', 'smith_machine', 'overhead_press'),
      ('dumbbell_lateral_raise', 'Dumbbell Lateral Raise', 'free_weight', 'dumbbell', 'lateral_raise'),
      ('cable_lateral_raise', 'Cable Lateral Raise', 'cable', 'cable', 'lateral_raise'),
      ('leaning_cable_lateral_raise', 'Leaning Cable Lateral Raise', 'cable', 'cable', 'lateral_raise'),
      ('machine_lateral_raise', 'Machine Lateral Raise', 'machine', 'lateral_raise_machine', 'lateral_raise'),
      ('dumbbell_front_raise', 'Dumbbell Front Raise', 'free_weight', 'dumbbell', 'front_raise'),
      ('plate_front_raise', 'Plate Front Raise', 'free_weight', 'plate', 'front_raise'),
      ('cable_front_raise', 'Cable Front Raise', 'cable', 'cable', 'front_raise'),
      ('reverse_pec_deck', 'Reverse Pec Deck', 'machine', 'pec_deck', 'rear_delt'),
      ('bent_over_dumbbell_reverse_fly', 'Bent Over Dumbbell Reverse Fly', 'free_weight', 'dumbbell', 'rear_delt'),
      ('cable_rear_delt_fly', 'Cable Rear Delt Fly', 'cable', 'cable', 'rear_delt'),
      ('upright_row', 'Upright Row', 'free_weight', 'barbell', 'upright_pull'),
      ('snatch_grip_high_pull', 'Snatch Grip High Pull', 'free_weight', 'barbell', 'upright_pull'),
      ('kettlebell_high_pull', 'Kettlebell High Pull', 'kettlebell', 'kettlebell', 'upright_pull'),
      ('handstand_push_up', 'Handstand Push Up', 'bodyweight', 'bodyweight', 'overhead_press'),
      ('pike_push_up', 'Pike Push Up', 'bodyweight', 'bodyweight', 'overhead_press'),
      ('cuban_press', 'Cuban Press', 'free_weight', 'dumbbell', 'rear_delt'),
      ('scarecrow_raise', 'Scarecrow Raise', 'cable', 'cable', 'rear_delt'),

      ('barbell_biceps_curl', 'Barbell Biceps Curl', 'free_weight', 'barbell', 'biceps_curl'),
      ('ez_bar_curl', 'EZ Bar Curl', 'free_weight', 'ez_bar', 'biceps_curl'),
      ('dumbbell_alternating_curl', 'Dumbbell Alternating Curl', 'free_weight', 'dumbbell', 'biceps_curl'),
      ('incline_dumbbell_curl', 'Incline Dumbbell Curl', 'free_weight', 'dumbbell', 'biceps_curl'),
      ('preacher_curl', 'Preacher Curl', 'free_weight', 'ez_bar', 'biceps_curl'),
      ('machine_preacher_curl', 'Machine Preacher Curl', 'machine', 'preacher_machine', 'biceps_curl'),
      ('cable_biceps_curl', 'Cable Biceps Curl', 'cable', 'cable', 'biceps_curl'),
      ('rope_hammer_curl', 'Rope Hammer Curl', 'cable', 'cable', 'biceps_hammer'),
      ('dumbbell_hammer_curl', 'Dumbbell Hammer Curl', 'free_weight', 'dumbbell', 'biceps_hammer'),
      ('cross_body_hammer_curl', 'Cross Body Hammer Curl', 'free_weight', 'dumbbell', 'biceps_hammer'),
      ('concentration_curl', 'Concentration Curl', 'free_weight', 'dumbbell', 'biceps_curl'),
      ('spider_curl', 'Spider Curl', 'free_weight', 'ez_bar', 'biceps_curl'),
      ('reverse_ez_bar_curl', 'Reverse EZ Bar Curl', 'free_weight', 'ez_bar', 'biceps_hammer'),
      ('zottman_curl', 'Zottman Curl', 'free_weight', 'dumbbell', 'biceps_hammer'),
      ('drag_curl', 'Drag Curl', 'free_weight', 'barbell', 'biceps_curl'),
      ('seated_incline_inner_biceps_curl', 'Seated Incline Inner Biceps Curl', 'free_weight', 'dumbbell', 'biceps_curl'),
      ('close_grip_bench_press', 'Close Grip Bench Press', 'free_weight', 'barbell', 'triceps_press'),
      ('skullcrusher', 'Skullcrusher', 'free_weight', 'ez_bar', 'triceps_extension'),
      ('ez_bar_skullcrusher', 'EZ Bar Skullcrusher', 'free_weight', 'ez_bar', 'triceps_extension'),
      ('lying_dumbbell_triceps_extension', 'Lying Dumbbell Triceps Extension', 'free_weight', 'dumbbell', 'triceps_extension'),
      ('overhead_dumbbell_triceps_extension', 'Overhead Dumbbell Triceps Extension', 'free_weight', 'dumbbell', 'triceps_extension'),
      ('cable_triceps_pushdown', 'Cable Triceps Pushdown', 'cable', 'cable', 'triceps_press'),
      ('rope_triceps_pushdown', 'Rope Triceps Pushdown', 'cable', 'cable', 'triceps_press'),
      ('reverse_grip_pushdown', 'Reverse Grip Pushdown', 'cable', 'cable', 'triceps_press'),
      ('overhead_cable_triceps_extension', 'Overhead Cable Triceps Extension', 'cable', 'cable', 'triceps_extension'),
      ('bench_dip', 'Bench Dip', 'bodyweight', 'bench', 'triceps_press'),
      ('weighted_bench_dip', 'Weighted Bench Dip', 'bodyweight', 'weighted_belt', 'triceps_press'),
      ('machine_triceps_extension', 'Machine Triceps Extension', 'machine', 'triceps_machine', 'triceps_extension'),
      ('diamond_push_up', 'Diamond Push Up', 'bodyweight', 'bodyweight', 'triceps_press'),
      ('triceps_kickback', 'Triceps Kickback', 'free_weight', 'dumbbell', 'triceps_extension'),
      ('cable_triceps_kickback', 'Cable Triceps Kickback', 'cable', 'cable', 'triceps_extension'),
      ('wrist_curl', 'Wrist Curl', 'free_weight', 'barbell', 'forearm_grip'),
      ('reverse_wrist_curl', 'Reverse Wrist Curl', 'free_weight', 'barbell', 'forearm_grip'),
      ('behind_back_wrist_curl', 'Behind Back Wrist Curl', 'free_weight', 'barbell', 'forearm_grip'),
      ('farmer_carry', 'Farmer Carry', 'free_weight', 'dumbbell', 'carry_pattern'),
      ('towel_hang', 'Towel Hang', 'bodyweight', 'pullup_bar', 'forearm_grip'),
      ('plate_pinch_hold', 'Plate Pinch Hold', 'free_weight', 'plate', 'forearm_grip'),
      ('wrist_roller', 'Wrist Roller', 'free_weight', 'wrist_roller', 'forearm_grip'),

      ('crunch', 'Crunch', 'bodyweight', 'bodyweight', 'abs_flexion'),
      ('decline_sit_up', 'Decline Sit Up', 'bodyweight', 'decline_bench', 'abs_flexion'),
      ('machine_crunch', 'Machine Crunch', 'machine', 'ab_machine', 'abs_flexion'),
      ('cable_crunch', 'Cable Crunch', 'cable', 'cable', 'abs_flexion'),
      ('bicycle_crunch', 'Bicycle Crunch', 'bodyweight', 'bodyweight', 'oblique_rotation'),
      ('reverse_crunch', 'Reverse Crunch', 'bodyweight', 'bodyweight', 'abs_flexion'),
      ('hanging_knee_raise', 'Hanging Knee Raise', 'bodyweight', 'pullup_bar', 'abs_flexion'),
      ('hanging_leg_raise', 'Hanging Leg Raise', 'bodyweight', 'pullup_bar', 'abs_flexion'),
      ('captain_chair_leg_raise', 'Captain Chair Leg Raise', 'machine', 'captain_chair', 'abs_flexion'),
      ('lying_leg_raise', 'Lying Leg Raise', 'bodyweight', 'bodyweight', 'abs_flexion'),
      ('dragon_flag', 'Dragon Flag', 'bodyweight', 'bodyweight', 'core_stability'),
      ('ab_wheel_rollout', 'Ab Wheel Rollout', 'bodyweight', 'ab_wheel', 'core_stability'),
      ('plank', 'Plank', 'bodyweight', 'bodyweight', 'core_stability'),
      ('side_plank', 'Side Plank', 'bodyweight', 'bodyweight', 'core_stability'),
      ('weighted_plank', 'Weighted Plank', 'bodyweight', 'weighted_plate', 'core_stability'),
      ('hollow_body_hold', 'Hollow Body Hold', 'bodyweight', 'bodyweight', 'core_stability'),
      ('v_up', 'V Up', 'bodyweight', 'bodyweight', 'abs_flexion'),
      ('russian_twist', 'Russian Twist', 'bodyweight', 'medicine_ball', 'oblique_rotation'),
      ('cable_woodchop', 'Cable Woodchop', 'cable', 'cable', 'oblique_rotation'),
      ('standing_cable_woodchop', 'Standing Cable Woodchop', 'cable', 'cable', 'oblique_rotation'),
      ('hanging_oblique_knee_raise', 'Hanging Oblique Knee Raise', 'bodyweight', 'pullup_bar', 'oblique_rotation'),
      ('medicine_ball_slam', 'Medicine Ball Slam', 'free_weight', 'medicine_ball', 'conditioning_upper'),
      ('dead_bug', 'Dead Bug', 'bodyweight', 'bodyweight', 'core_stability'),
      ('bird_dog', 'Bird Dog', 'bodyweight', 'bodyweight', 'core_stability'),
      ('pallof_press', 'Pallof Press', 'cable', 'cable', 'core_stability'),
      ('suitcase_carry', 'Suitcase Carry', 'free_weight', 'dumbbell', 'carry_pattern'),
      ('back_extension', 'Back Extension', 'bodyweight', 'roman_chair', 'posterior_extension'),
      ('glute_ham_back_extension', 'Glute Ham Back Extension', 'machine', 'ghd', 'posterior_extension'),
      ('superman_hold', 'Superman Hold', 'bodyweight', 'bodyweight', 'posterior_extension'),
      ('ghd_sit_up', 'GHD Sit Up', 'machine', 'ghd', 'abs_flexion'),

      ('back_squat', 'Back Squat', 'free_weight', 'barbell', 'squat_pattern'),
      ('front_squat', 'Front Squat', 'free_weight', 'barbell', 'squat_pattern'),
      ('high_bar_back_squat', 'High Bar Back Squat', 'free_weight', 'barbell', 'squat_pattern'),
      ('low_bar_back_squat', 'Low Bar Back Squat', 'free_weight', 'barbell', 'squat_pattern'),
      ('safety_bar_squat', 'Safety Bar Squat', 'free_weight', 'safety_bar', 'squat_pattern'),
      ('zercher_squat', 'Zercher Squat', 'free_weight', 'barbell', 'squat_pattern'),
      ('goblet_squat', 'Goblet Squat', 'free_weight', 'dumbbell', 'squat_pattern'),
      ('dumbbell_split_squat', 'Dumbbell Split Squat', 'free_weight', 'dumbbell', 'single_leg_pattern'),
      ('bulgarian_split_squat', 'Bulgarian Split Squat', 'free_weight', 'dumbbell', 'single_leg_pattern'),
      ('barbell_lunge', 'Barbell Lunge', 'free_weight', 'barbell', 'lunge_pattern'),
      ('dumbbell_walking_lunge', 'Dumbbell Walking Lunge', 'free_weight', 'dumbbell', 'lunge_pattern'),
      ('reverse_lunge', 'Reverse Lunge', 'free_weight', 'dumbbell', 'lunge_pattern'),
      ('curtsy_lunge', 'Curtsy Lunge', 'free_weight', 'dumbbell', 'lunge_pattern'),
      ('cossack_squat', 'Cossack Squat', 'bodyweight', 'bodyweight', 'single_leg_pattern'),
      ('step_up', 'Step Up', 'free_weight', 'dumbbell', 'single_leg_pattern'),
      ('high_box_step_up', 'High Box Step Up', 'free_weight', 'dumbbell', 'single_leg_pattern'),
      ('hack_squat', 'Hack Squat', 'free_weight', 'barbell', 'squat_pattern'),
      ('machine_hack_squat', 'Machine Hack Squat', 'machine', 'hack_squat_machine', 'squat_pattern'),
      ('leg_press', 'Leg Press', 'machine', 'leg_press_machine', 'leg_press_pattern'),
      ('single_leg_press', 'Single Leg Press', 'machine', 'leg_press_machine', 'leg_press_pattern'),
      ('belt_squat', 'Belt Squat', 'machine', 'belt_squat_machine', 'squat_pattern'),
      ('smith_machine_squat', 'Smith Machine Squat', 'machine', 'smith_machine', 'squat_pattern'),
      ('smith_machine_split_squat', 'Smith Machine Split Squat', 'machine', 'smith_machine', 'single_leg_pattern'),
      ('leg_extension', 'Leg Extension', 'machine', 'leg_extension_machine', 'leg_extension_pattern'),
      ('single_leg_extension', 'Single Leg Extension', 'machine', 'leg_extension_machine', 'leg_extension_pattern'),
      ('seated_leg_curl', 'Seated Leg Curl', 'machine', 'leg_curl_machine', 'hamstring_curl_pattern'),
      ('lying_leg_curl', 'Lying Leg Curl', 'machine', 'leg_curl_machine', 'hamstring_curl_pattern'),
      ('standing_leg_curl', 'Standing Leg Curl', 'machine', 'leg_curl_machine', 'hamstring_curl_pattern'),
      ('nordic_hamstring_curl', 'Nordic Hamstring Curl', 'bodyweight', 'bodyweight', 'hamstring_curl_pattern'),
      ('glute_ham_raise', 'Glute Ham Raise', 'machine', 'ghd', 'hamstring_curl_pattern'),
      ('romanian_deadlift_dumbbell', 'Romanian Deadlift Dumbbell', 'free_weight', 'dumbbell', 'hip_hinge_pattern'),
      ('good_morning', 'Good Morning', 'free_weight', 'barbell', 'hip_hinge_pattern'),
      ('barbell_hip_thrust', 'Barbell Hip Thrust', 'free_weight', 'barbell', 'hip_thrust_pattern'),
      ('smith_machine_hip_thrust', 'Smith Machine Hip Thrust', 'machine', 'smith_machine', 'hip_thrust_pattern'),
      ('glute_bridge', 'Glute Bridge', 'bodyweight', 'bodyweight', 'hip_thrust_pattern'),
      ('single_leg_glute_bridge', 'Single Leg Glute Bridge', 'bodyweight', 'bodyweight', 'hip_thrust_pattern'),
      ('cable_pull_through', 'Cable Pull Through', 'cable', 'cable', 'hip_hinge_pattern'),
      ('kettlebell_swing', 'Kettlebell Swing', 'kettlebell', 'kettlebell', 'kettlebell_ballistic'),
      ('sumo_kettlebell_deadlift', 'Sumo Kettlebell Deadlift', 'kettlebell', 'kettlebell', 'hip_hinge_pattern'),
      ('single_leg_romanian_deadlift', 'Single Leg Romanian Deadlift', 'free_weight', 'dumbbell', 'hip_hinge_pattern'),
      ('hip_abduction_machine', 'Hip Abduction Machine', 'machine', 'hip_abduction_machine', 'abduction_pattern'),
      ('cable_hip_abduction', 'Cable Hip Abduction', 'cable', 'cable', 'abduction_pattern'),
      ('mini_band_lateral_walk', 'Mini Band Lateral Walk', 'band', 'mini_band', 'abduction_pattern'),
      ('clamshell', 'Clamshell', 'band', 'mini_band', 'abduction_pattern'),
      ('hip_adduction_machine', 'Hip Adduction Machine', 'machine', 'hip_adduction_machine', 'adduction_pattern'),
      ('cable_hip_adduction', 'Cable Hip Adduction', 'cable', 'cable', 'adduction_pattern'),
      ('seated_calf_raise', 'Seated Calf Raise', 'machine', 'calf_raise_machine', 'calf_pattern'),
      ('standing_calf_raise', 'Standing Calf Raise', 'machine', 'calf_raise_machine', 'calf_pattern'),
      ('leg_press_calf_raise', 'Leg Press Calf Raise', 'machine', 'leg_press_machine', 'calf_pattern'),
      ('donkey_calf_raise', 'Donkey Calf Raise', 'machine', 'donkey_calf_machine', 'calf_pattern'),
      ('single_leg_calf_raise', 'Single Leg Calf Raise', 'bodyweight', 'bodyweight', 'calf_pattern'),
      ('tibialis_raise', 'Tibialis Raise', 'bodyweight', 'tib_bar', 'tibialis_pattern'),
      ('sled_push', 'Sled Push', 'strongman', 'sled', 'sled_pattern'),
      ('sled_pull', 'Sled Pull', 'strongman', 'sled', 'sled_pattern'),
      ('prowler_push', 'Prowler Push', 'strongman', 'prowler', 'sled_pattern'),
      ('broad_jump', 'Broad Jump', 'plyometric', 'bodyweight', 'plyometric_lower'),
      ('box_jump', 'Box Jump', 'plyometric', 'plyo_box', 'plyometric_lower'),
      ('jump_squat', 'Jump Squat', 'plyometric', 'bodyweight', 'plyometric_lower'),
      ('trap_bar_deadlift', 'Trap Bar Deadlift', 'free_weight', 'trap_bar', 'deadlift_pattern'),
      ('trap_bar_jump', 'Trap Bar Jump', 'free_weight', 'trap_bar', 'plyometric_lower'),
      ('barbell_thruster', 'Barbell Thruster', 'free_weight', 'barbell', 'full_body_power'),
      ('dumbbell_thruster', 'Dumbbell Thruster', 'free_weight', 'dumbbell', 'full_body_power'),
      ('clean_pull', 'Clean Pull', 'olympic', 'barbell', 'olympic_pull'),
      ('power_clean', 'Power Clean', 'olympic', 'barbell', 'olympic_lift'),
      ('hang_power_clean', 'Hang Power Clean', 'olympic', 'barbell', 'olympic_lift'),
      ('power_snatch', 'Power Snatch', 'olympic', 'barbell', 'olympic_lift'),
      ('hang_power_snatch', 'Hang Power Snatch', 'olympic', 'barbell', 'olympic_lift'),
      ('clean_and_jerk', 'Clean And Jerk', 'olympic', 'barbell', 'olympic_lift'),
      ('split_jerk', 'Split Jerk', 'olympic', 'barbell', 'olympic_lift'),
      ('snatch_balance', 'Snatch Balance', 'olympic', 'barbell', 'olympic_lift'),
      ('turkish_get_up', 'Turkish Get Up', 'kettlebell', 'kettlebell', 'full_body_power'),
      ('kettlebell_clean_and_press', 'Kettlebell Clean And Press', 'kettlebell', 'kettlebell', 'kettlebell_ballistic'),
      ('kettlebell_snatch', 'Kettlebell Snatch', 'kettlebell', 'kettlebell', 'kettlebell_ballistic'),
      ('battle_rope_slam', 'Battle Rope Slam', 'cable', 'battle_rope', 'conditioning_upper'),
      ('battle_rope_wave', 'Battle Rope Wave', 'cable', 'battle_rope', 'conditioning_upper'),
      ('rowing_ergometer_sprint', 'Rowing Ergometer Sprint', 'cardio', 'rowing_erg', 'conditioning_cardio'),
      ('assault_bike_sprint', 'Assault Bike Sprint', 'cardio', 'assault_bike', 'conditioning_cardio'),
      ('ski_erg_sprint', 'Ski Erg Sprint', 'cardio', 'ski_erg', 'conditioning_cardio'),
      ('burpee', 'Burpee', 'bodyweight', 'bodyweight', 'burpee_pattern'),
      ('burpee_pull_up', 'Burpee Pull Up', 'bodyweight', 'pullup_bar', 'burpee_pattern'),
      ('mountain_climber', 'Mountain Climber', 'bodyweight', 'bodyweight', 'crawl_pattern'),
      ('bear_crawl', 'Bear Crawl', 'bodyweight', 'bodyweight', 'crawl_pattern'),
      ('sandbag_front_carry', 'Sandbag Front Carry', 'strongman', 'sandbag', 'carry_pattern'),
      ('sandbag_shoulder_to_shoulder', 'Sandbag Shoulder To Shoulder', 'strongman', 'sandbag', 'strongman_load'),
      ('yoke_walk', 'Yoke Walk', 'strongman', 'yoke', 'strongman_load'),
      ('atlas_stone_load', 'Atlas Stone Load', 'strongman', 'atlas_stone', 'strongman_load'),
      ('tire_flip', 'Tire Flip', 'strongman', 'tire', 'strongman_load'),
      ('rope_climb', 'Rope Climb', 'bodyweight', 'rope', 'climb_pattern'),
      ('stair_sprint', 'Stair Sprint', 'cardio', 'stairs', 'conditioning_cardio'),
      ('weighted_stepmill_climb', 'Weighted Stepmill Climb', 'cardio', 'stepmill', 'conditioning_cardio'),
      ('jump_rope_double_under', 'Jump Rope Double Under', 'cardio', 'jump_rope', 'plyometric_lower'),
      ('medicine_ball_rotational_throw', 'Medicine Ball Rotational Throw', 'free_weight', 'medicine_ball', 'rotational_throw')
  ) as t(slug, name, category, equipment, group_code)
),
upsert_exercises as (
  insert into public.exercises (slug, name, category, exercise_type, muscle_size, equipment)
  select
    es.slug,
    es.name,
    es.category,
    case
      when es.category = 'cardio' then 'cardio'
      else 'weight'
    end as exercise_type,
    case
      when es.category = 'cardio' then 'large'
      when egs.primary_muscle_code in (
        'chest', 'upper_chest', 'lats', 'rhomboids', 'spinal_erectors',
        'quadriceps', 'hamstrings', 'glutes', 'adductors', 'abductors'
      ) then 'large'
      else 'small'
    end as muscle_size,
    es.equipment
  from exercise_seed es
  join exercise_group_seed egs
    on egs.group_code = es.group_code
  on conflict (slug) do update
  set
    name = excluded.name,
    category = excluded.category,
    exercise_type = excluded.exercise_type,
    muscle_size = excluded.muscle_size,
    equipment = excluded.equipment,
    updated_at = now()
  returning id, slug
),
exercise_rows as (
  select
    ue.id as exercise_id,
    es.slug,
    egs.primary_muscle_code,
    egs.secondary_muscle_codes
  from upsert_exercises ue
  join exercise_seed es
    on es.slug = ue.slug
  join exercise_group_seed egs
    on egs.group_code = es.group_code
),
mapping_seed as (
  select
    er.exercise_id,
    er.primary_muscle_code as muscle_code,
    'primary'::text as role
  from exercise_rows er

  union all

  select
    er.exercise_id,
    smc.muscle_code,
    'secondary'::text as role
  from exercise_rows er
  cross join lateral unnest(er.secondary_muscle_codes) as smc(muscle_code)
),
resolved_mapping as (
  select
    ms.exercise_id,
    m.id as muscle_id,
    ms.role
  from mapping_seed ms
  join public.muscles m
    on m.code = ms.muscle_code
)
insert into public.exercise_muscle_mapping (exercise_id, muscle_id, role)
select
  rm.exercise_id,
  rm.muscle_id,
  rm.role
from resolved_mapping rm
on conflict (exercise_id, muscle_id) do update
set
  role = excluded.role,
  updated_at = now();

commit;
