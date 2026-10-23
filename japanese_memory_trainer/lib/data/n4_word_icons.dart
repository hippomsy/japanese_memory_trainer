// 2026-10-21 N4 단어장(딱! 한권 JLPT 단어장 N4) 단어별 그림(머티리얼 아이콘) 표.
// 단어 뜻에 맞는 아이콘을 하나씩 골라 두었다. 릴리스 빌드의 아이콘 트리 쉐이킹이 되도록
// 모두 const Icons.* 로 적는다. 새 단어가 생기면 여기에 한 줄 추가한다(없으면 DAY 주제 아이콘).
import 'package:flutter/material.dart';

const Map<String, IconData> n4WordIcons = <String, IconData>{
  // DAY 01 인간관계
  'd01_01': Icons.waving_hand_rounded, // 挨拶 인사
  'd01_02': Icons.back_hand_rounded, // 遠慮 사양
  'd01_03': Icons.celebration_rounded, // お祝い 축하
  'd01_04': Icons.volunteer_activism_rounded, // おかげ 덕택
  'd01_05': Icons.room_service_rounded, // お客さん 손님
  'd01_06': Icons.favorite_rounded, // お見合い 맞선
  'd01_07': Icons.redeem_rounded, // お礼 사례
  'd01_08': Icons.diamond_rounded, // 結婚 결혼
  'd01_09': Icons.connect_without_contact_rounded, // 紹介 소개
  'd01_10': Icons.mail_rounded, // 招待 초대
  'd01_11': Icons.check_circle_rounded, // 承知 알아들음
  'd01_12': Icons.woman_rounded, // 女性 여성
  'd01_13': Icons.child_care_rounded, // 世話 도와줌
  'd01_14': Icons.forum_rounded, // 相談 상담
  'd01_15': Icons.man_rounded, // 男性 남성
  'd01_16': Icons.chat_rounded, // 話 이야기
  'd01_17': Icons.history_rounded, // 久しぶり 오래간만
  'd01_18': Icons.handshake_rounded, // 約束 약속
  'd01_19': Icons.card_giftcard_rounded, // あげる・やる (내가 남에게) 주다
  'd01_20': Icons.card_membership_rounded, // くれる (남이 나에게) 주다
  'd01_21': Icons.verified_rounded, // 信じる 믿다
  'd01_22': Icons.contact_support_rounded, // 尋ねる 묻다
  'd01_23': Icons.door_front_door_rounded, // 訪ねる 방문하다
  'd01_24': Icons.emoji_people_rounded, // 頼む 부탁하다
  'd01_25': Icons.support_rounded, // 手伝う 돕다
  'd01_26': Icons.hourglass_empty_rounded, // 待つ 기다리다
  'd01_27': Icons.move_to_inbox_rounded, // もらう 받다
  'd01_28': Icons.heart_broken_rounded, // 別れる 헤어지다
  // DAY 02 가족
  'd02_01': Icons.baby_changing_station_rounded, // 赤ん坊 갓난아기
  'd02_02': Icons.man_2_rounded, // 兄 형
  'd02_03': Icons.face_3_rounded, // 姉 누나
  'd02_04': Icons.face_4_rounded, // 妹 여동생
  'd02_05': Icons.masks_rounded, // 嘘 거짓말
  'd02_06': Icons.chat_bubble_rounded, // おしゃべり 수다
  'd02_07': Icons.cottage_rounded, // お宅 댁
  'd02_08': Icons.man_3_rounded, // 夫 남편
  'd02_09': Icons.face_6_rounded, // 弟 남동생
  'd02_10': Icons.escalator_warning_rounded, // 親 어버이
  'd02_11': Icons.diversity_3_rounded, // 家族 가족
  'd02_12': Icons.home_rounded, // 家内 (자기의) 아내
  'd02_13': Icons.hub_rounded, // 関係 관계
  'd02_14': Icons.people_rounded, // 兄弟 형제
  'd02_15': Icons.person_rounded, // 自分 자기
  'd02_16': Icons.man_4_rounded, // 主人 남편
  'd02_17': Icons.mood_rounded, // 冗談 농담
  'd02_18': Icons.elderly_rounded, // 祖父 조부
  'd02_19': Icons.elderly_woman_rounded, // 祖母 조모
  'd02_20': Icons.man_rounded, // 父親 부친
  'd02_21': Icons.woman_rounded, // 妻 아내
  'd02_22': Icons.woman_2_rounded, // 母親 모친
  'd02_23': Icons.boy_rounded, // 息子 아들
  'd02_24': Icons.girl_rounded, // 娘 딸
  'd02_25': Icons.family_restroom_rounded, // 両親 부모님
  'd02_26': Icons.handshake_rounded, // 会う 만나다
  'd02_27': Icons.child_friendly_rounded, // 生まれる 태어나다
  'd02_28': Icons.question_answer_rounded, // 答える 대답하다
  'd02_29': Icons.campaign_rounded, // 騒ぐ 떠들다
  'd02_30': Icons.flare_rounded, // 光る 빛나다
  'd02_31': Icons.directions_walk_rounded, // 連れる 데리고 오다
  'd02_32': Icons.compare_rounded, // 似る 닮다
  'd02_33': Icons.waving_hand_rounded, // 迎える 맞이하다
  'd02_34': Icons.record_voice_over_rounded, // 呼ぶ 부르다
  'd02_35': Icons.star_rounded, // 特別な 특별한
  // DAY 03 기분
  'd03_01': Icons.sentiment_satisfied_rounded, // 安心 안심
  'd03_02': Icons.auto_awesome_rounded, // 感動 감동
  'd03_03': Icons.emoji_emotions_rounded, // 気分 기분
  'd03_04': Icons.volunteer_activism_rounded, // 気持ち 기분
  'd03_05': Icons.self_improvement_rounded, // 心 마음
  'd03_06': Icons.sentiment_very_dissatisfied_rounded, // 怒る 화내다
  'd03_07': Icons.priority_high_rounded, // 驚く 놀라다
  'd03_08': Icons.psychology_rounded, // 思う 생각하다
  'd03_09': Icons.lightbulb_rounded, // 考える 생각하다
  'd03_10': Icons.report_problem_rounded, // 困る 곤란하다
  'd03_11': Icons.water_drop_rounded, // 泣く 울다
  'd03_12': Icons.celebration_rounded, // 喜ぶ 기뻐하다
  'd03_13': Icons.sentiment_very_satisfied_rounded, // 笑う 웃다
  'd03_14': Icons.mood_rounded, // 嬉しい 기쁘다
  'd03_15': Icons.mood_bad_rounded, // 悲しい 슬프다
  'd03_16': Icons.dark_mode_rounded, // 暗い 어둡다
  'd03_17': Icons.warning_rounded, // 怖い 무섭다
  'd03_18': Icons.person_off_rounded, // 寂しい 쓸쓸하다
  'd03_19': Icons.thumb_up_rounded, // すごい 굉장하다
  'd03_20': Icons.history_rounded, // 懐かしい 그립다
  'd03_21': Icons.visibility_off_rounded, // 恥ずかしい 부끄럽다
  'd03_22': Icons.thumb_down_rounded, // ひどい 심하다
  'd03_23': Icons.shopping_cart_rounded, // 欲しい 갖고 싶다
  'd03_24': Icons.block_rounded, // 嫌な 싫은
  'd03_25': Icons.heart_broken_rounded, // 嫌いな 싫어하는
  'd03_26': Icons.check_circle_rounded, // 結構な 괜찮은
  'd03_27': Icons.sentiment_dissatisfied_rounded, // 残念な 유감스러운
  'd03_28': Icons.psychology_alt_rounded, // 心配な 걱정스러운
  'd03_29': Icons.favorite_rounded, // 好きな 좋아하는
  'd03_30': Icons.diamond_rounded, // 大事な 소중한
  'd03_31': Icons.star_rounded, // 大切な 중요한
  'd03_32': Icons.monitor_heart_rounded, // どきどき 두근두근
  'd03_33': Icons.new_releases_rounded, // びっくり 깜짝 놀람
  'd03_34': Icons.visibility_rounded, // 気にする 신경 쓰다
  'd03_35': Icons.help_rounded, // 気になる 신경 쓰이다
  // DAY 04 태도
  'd04_01': Icons.fact_check_rounded, // 確認 확인
  'd04_02': Icons.bolt_rounded, // 緊張 긴장
  'd04_03': Icons.thumb_up_rounded, // 賛成 찬성
  'd04_04': Icons.repeat_rounded, // 習慣 습관
  'd04_05': Icons.error_outline_rounded, // 心配 걱정
  'd04_06': Icons.category_rounded, // タイプ 타입
  'd04_07': Icons.thumb_down_rounded, // 反対 반대
  'd04_08': Icons.sentiment_dissatisfied_rounded, // 謝る 사과하다
  'd04_09': Icons.lightbulb_rounded, // 思い出す 생각해 내다
  'd04_10': Icons.fitness_center_rounded, // 頑張る 분발하다
  'd04_11': Icons.celebration_rounded, // 楽しむ 즐기다
  'd04_12': Icons.light_mode_rounded, // 明るい 밝다
  'd04_13': Icons.volume_up_rounded, // うるさい 시끄럽다
  'd04_14': Icons.question_mark_rounded, // おかしい 이상하다
  'd04_15': Icons.self_improvement_rounded, // 大人しい 얌전하다
  'd04_16': Icons.scale_rounded, // 重い 무겁다
  'd04_17': Icons.gavel_rounded, // 厳しい 엄하다
  'd04_18': Icons.emoji_events_rounded, // 素晴らしい 훌륭하다
  'd04_19': Icons.sentiment_very_satisfied_rounded, // 楽しい 즐겁다
  'd04_20': Icons.volunteer_activism_rounded, // 優しい 상냥하다
  'd04_21': Icons.recommend_rounded, // よろしい 좋다
  'd04_22': Icons.face_rounded, // 若い 젊다
  'd04_23': Icons.thumb_down_rounded, // 悪い 나쁘다
  'd04_24': Icons.volume_off_rounded, // 静かな 조용한
  'd04_25': Icons.do_not_disturb_rounded, // 失礼な 무례한
  'd04_26': Icons.volunteer_activism_rounded, // 親切な 친절한
  'd04_27': Icons.cloud_rounded, // ソフトな 소프트한
  'd04_28': Icons.check_circle_rounded, // 大丈夫な 괜찮은
  'd04_29': Icons.cancel_rounded, // 駄目な 좋지 않은
  'd04_30': Icons.workspace_premium_rounded, // 丁寧な 정중한
  'd04_31': Icons.local_fire_department_rounded, // 熱心な 열심인
  'd04_32': Icons.psychology_alt_rounded, // 変な 이상한
  'd04_33': Icons.verified_user_rounded, // 真面目な 성실한
  'd04_34': Icons.lock_rounded, // しっかり 단단히
  'd04_35': Icons.priority_high_rounded, // 特に 특히
  // DAY 05 디자인과 패션
  'd05_01': Icons.diamond_rounded, // アクセサリー 액세서리
  'd05_02': Icons.palette_rounded, // 色 색
  'd05_03': Icons.checkroom_rounded, // 上着 겉옷
  'd05_04': Icons.category_rounded, // 形 형태
  'd05_05': Icons.accessibility_rounded, // 格好 모습
  'd05_06': Icons.straighten_rounded, // サイズ 사이즈
  'd05_07': Icons.beach_access_rounded, // サンダル 샌들
  'd05_08': Icons.dry_cleaning_rounded, // 下着 속옷
  'd05_09': Icons.checkroom_rounded, // 試着 옷이 맞는지 입어 봄
  'd05_10': Icons.business_center_rounded, // スーツ 슈트
  'd05_11': Icons.checkroom_rounded, // セーター 스웨터
  'd05_12': Icons.palette_rounded, // 茶色 갈색
  'd05_13': Icons.back_hand_rounded, // 手袋 장갑
  'd05_14': Icons.watch_rounded, // 時計 시계
  'd05_15': Icons.radio_button_checked_rounded, // ボタン 단추
  'd05_16': Icons.grass_rounded, // 木綿 면
  'd05_17': Icons.diamond_rounded, // 指輪 반지
  'd05_18': Icons.checkroom_rounded, // 洋服 양복
  'd05_19': Icons.dry_cleaning_rounded, // Yシャツ 와이셔츠
  'd05_20': Icons.check_rounded, // 合う 맞다
  'd05_21': Icons.auto_awesome_rounded, // 飾る 장식하다
  'd05_22': Icons.checkroom_rounded, // 着る (옷을) 입다
  'd05_23': Icons.push_pin_rounded, // 付く 붙다
  'd05_24': Icons.link_off_rounded, // 取れる 떨어지다
  'd05_25': Icons.thumb_up_rounded, // 似合う 어울리다
  'd05_26': Icons.ice_skating_rounded, // 履く 신다
  'd05_27': Icons.remove_circle_rounded, // 外す 떼다
  'd05_28': Icons.face_retouching_natural_rounded, // かぶる (모자를) 쓰다
  'd05_29': Icons.change_circle_rounded, // 変える 바꾸다
  'd05_30': Icons.autorenew_rounded, // 変わる 변하다
  'd05_31': Icons.water_drop_rounded, // 青い 파랗다
  'd05_32': Icons.local_fire_department_rounded, // 赤い 빨갛다
  'd05_33': Icons.layers_rounded, // 厚い 두껍다
  'd05_34': Icons.dark_mode_rounded, // 黒い 검다
  'd05_35': Icons.compress_rounded, // 小さい 작다
  'd05_36': Icons.line_weight_rounded, // 太い 굵다
  'd05_37': Icons.history_rounded, // 古い 오래되다
  'd05_38': Icons.horizontal_rule_rounded, // 細い 가늘다
  'd05_39': Icons.short_text_rounded, // 短い 짧다
  'd05_40': Icons.drag_handle_rounded, // 同じ 같음
  'd05_41': Icons.auto_awesome_rounded, // きれいな 예쁜
  // DAY 06 일상생활 ①
  'd06_01': Icons.iron_rounded, // アイロン 다리미
  'd06_02': Icons.gesture_rounded, // 糸 실
  'd06_03': Icons.pets_rounded, // 犬 개
  'd06_04': Icons.redeem_rounded, // 贈り物 선물
  'd06_05': Icons.toys_rounded, // おもちゃ 장난감
  'd06_06': Icons.curtains_rounded, // カーテン 커튼
  'd06_07': Icons.window_rounded, // ガラス 유리
  'd06_08': Icons.calendar_month_rounded, // カレンダー 달력
  'd06_09': Icons.recycling_rounded, // 缶 깡통
  'd06_10': Icons.texture_rounded, // 毛 털
  'd06_11': Icons.brush_rounded, // 化粧 화장
  'd06_12': Icons.delete_rounded, // ゴミ 쓰레기
  'd06_13': Icons.schedule_rounded, // 支度 준비
  'd06_14': Icons.home_rounded, // 生活 생활
  'd06_15': Icons.weekend_rounded, // ソファー 소파
  'd06_16': Icons.dry_rounded, // タオル 타월
  'd06_17': Icons.layers_rounded, // 電池 전지
  'd06_18': Icons.battery_full_rounded, // 人形 인형
  'd06_19': Icons.smart_toy_rounded, // 寝坊 늦잠
  'd06_20': Icons.snooze_rounded, // パーティー 파티
  'd06_21': Icons.celebration_rounded, // 便 편
  'd06_22': Icons.local_shipping_rounded, // 普通 보통
  'd06_23': Icons.commute_rounded, // 布団 이불
  'd06_24': Icons.bed_rounded, // リモコン 리모컨
  'd06_25': Icons.settings_remote_rounded, // 遊ぶ 놀다
  'd06_26': Icons.toys_rounded, // 起きる 일어나다
  'd06_27': Icons.alarm_rounded, // 起こす 일으키다
  'd06_28': Icons.accessibility_new_rounded, // 飼う 기르다
  'd06_29': Icons.pets_rounded, // 出かける 외출하다
  'd06_30': Icons.directions_walk_rounded, // 出る 나오다
  'd06_31': Icons.logout_rounded, // 止める (수도 등을) 잠그다
  'd06_32': Icons.water_damage_rounded, // 脱ぐ 벗다
  'd06_33': Icons.sports_esports_rounded, // やる 하다
  'd06_34': Icons.cleaning_services_rounded, // 汚す 더럽히다
  'd06_35': Icons.water_drop_rounded, // 汚れる 더러워지다
  // DAY 07 일상생활 ② 우리 집
  'd07_01': Icons.meeting_room_rounded, // 入口 입구
  'd07_02': Icons.roofing_rounded, // 屋上 옥상
  'd07_03': Icons.door_sliding_rounded, // 押し入れ 붙박이장
  'd07_04': Icons.face_retouching_natural_rounded, // 鏡 거울
  'd07_05': Icons.cleaning_services_rounded, // 家事 가사
  'd07_06': Icons.kitchen_rounded, // 家電 가전
  'd07_07': Icons.water_rounded, // 水道 수도
  'd07_08': Icons.local_laundry_service_rounded, // 洗濯 세탁
  'd07_09': Icons.cleaning_services_rounded, // 掃除 청소
  'd07_10': Icons.directions_car_rounded, // 台 대(차·기계 등을 세는 말)
  'd07_11': Icons.kitchen_rounded, // 台所 부엌
  'd07_12': Icons.grid_on_rounded, // 畳 다다미
  'd07_13': Icons.view_agenda_rounded, // 棚 선반
  'd07_14': Icons.menu_book_rounded, // 使い方 사용법
  'd07_15': Icons.electric_bolt_rounded, // 電気 전기
  'd07_16': Icons.roofing_rounded, // 天井 천장
  'd07_17': Icons.lightbulb_rounded, // 電灯 전등
  'd07_18': Icons.bed_rounded, // 部屋 방
  'd07_19': Icons.fence_rounded, // 門 문
  'd07_20': Icons.roofing_rounded, // 屋根 지붕
  'd07_21': Icons.layers_rounded, // 床 바닥
  'd07_22': Icons.back_hand_rounded, // 置く 놓다
  'd07_23': Icons.checkroom_rounded, // かける (높은 곳에) 걸다
  'd07_24': Icons.inventory_rounded, // 片付く 정리되다
  'd07_25': Icons.inventory_2_rounded, // 片付ける 정리하다
  'd07_26': Icons.lightbulb_outline_rounded, // 消える 꺼지다
  'd07_27': Icons.battery_alert_rounded, // 切れる 다 되다
  'd07_28': Icons.power_settings_new_rounded, // 消す 끄다
  'd07_29': Icons.delete_rounded, // 捨てる 버리다
  'd07_30': Icons.touch_app_rounded, // 使う 사용하다
  'd07_31': Icons.toggle_on_rounded, // つける 붙이다
  'd07_32': Icons.close_fullscreen_rounded, // 閉じる 닫히다
  'd07_33': Icons.back_hand_rounded, // 拾う 줍다
  'd07_34': Icons.wash_rounded, // 拭く 닦다
  'd07_35': Icons.local_fire_department_rounded, // 燃える 타다
  // DAY 08 일상생활 ③ 마을
  'd08_01': Icons.wallpaper_rounded, // 壁 벽
  'd08_02': Icons.local_cafe_rounded, // 喫茶店 찻집
  'd08_03': Icons.church_rounded, // 教会 교회
  'd08_04': Icons.park_rounded, // 公園 공원
  'd08_05': Icons.location_city_rounded, // 市町村 시정촌(일본의 행정 구역 명칭
  'd08_06': Icons.apartment_rounded, // 建物 건물
  'd08_07': Icons.stairs_rounded, // 地下 지하
  'd08_08': Icons.temple_buddhist_rounded, // 寺 절
  'd08_09': Icons.pets_rounded, // 動物園 동물원
  'd08_10': Icons.location_city_rounded, // 都会 도회
  'd08_11': Icons.house_rounded, // 二階建て 2층집
  'd08_12': Icons.content_cut_rounded, // 美容院 미용실
  'd08_13': Icons.groups_rounded, // 広場 광장
  'd08_14': Icons.local_library_rounded, // 本屋 서점
  'd08_15': Icons.location_city_rounded, // 町 시가지
  'd08_16': Icons.holiday_village_rounded, // 村 마을
  'd08_17': Icons.forest_rounded, // 木製 목제
  'd08_18': Icons.restaurant_rounded, // レストラン 레스토랑
  'd08_19': Icons.door_sliding_rounded, // 開く 열리다
  'd08_20': Icons.meeting_room_rounded, // 開ける 열다
  'd08_21': Icons.self_improvement_rounded, // 祈る 기도하다
  'd08_22': Icons.door_back_door_rounded, // 閉める 닫다
  'd08_23': Icons.skip_next_rounded, // 過ぎる 지나다
  'd08_24': Icons.house_rounded, // 住む 살다
  'd08_25': Icons.accessibility_new_rounded, // 立つ 서다
  'd08_26': Icons.apartment_rounded, // 建つ (건물이) 세워지다
  'd08_27': Icons.flag_rounded, // 立てる 세우다
  'd08_28': Icons.construction_rounded, // 建てる (건물을) 짓다
  'd08_29': Icons.check_circle_rounded, // できる 할 수 있다
  'd08_30': Icons.swap_horiz_rounded, // 取り替える 바꾸다
  'd08_31': Icons.cleaning_services_rounded, // 掃く 쓸다
  'd08_32': Icons.local_shipping_rounded, // 引っ越す 이사하다
  'd08_33': Icons.delete_rounded, // 汚い 더럽다
  'd08_34': Icons.open_in_full_rounded, // 広い 넓다
  'd08_35': Icons.celebration_rounded, // 賑やかな 활기찬
  // DAY 09 식생활 ① 맛
  'd09_01': Icons.restaurant_rounded, // 味 맛
  'd09_02': Icons.hot_tub_rounded, // お湯 뜨거운 물
  'd09_03': Icons.room_service_rounded, // ご馳走 대접함
  'd09_04': Icons.dinner_dining_rounded, // 食事 식사
  'd09_05': Icons.local_dining_rounded, // 食堂 식당
  'd09_06': Icons.fastfood_rounded, // 食品 식품
  'd09_07': Icons.shopping_basket_rounded, // 食料品 식료품
  'd09_08': Icons.flatware_rounded, // 食器 식기
  'd09_09': Icons.handyman_rounded, // 道具 도구
  'd09_10': Icons.air_rounded, // 匂い 냄새
  'd09_11': Icons.lunch_dining_rounded, // 昼ご飯 점심
  'd09_12': Icons.dinner_dining_rounded, // 夕食 저녁 식사
  'd09_13': Icons.sentiment_satisfied_rounded, // 噛む 씹다
  'd09_14': Icons.ac_unit_rounded, // 冷める 식다
  'd09_15': Icons.format_paint_rounded, // 塗る 바르다
  'd09_16': Icons.more_horiz_rounded, // 残る 남다
  'd09_17': Icons.local_drink_rounded, // 飲む 마시다
  'd09_18': Icons.ac_unit_rounded, // 冷える 차가워지다
  'd09_19': Icons.kitchen_rounded, // 冷やす 식히다
  'd09_20': Icons.outdoor_grill_rounded, // 焼く 태우다
  'd09_21': Icons.local_fire_department_rounded, // 焼ける 구워지다
  'd09_22': Icons.soup_kitchen_rounded, // 沸かす (물을) 끓이다
  'd09_23': Icons.soup_kitchen_rounded, // 沸く 끓다
  'd09_24': Icons.coffee_rounded, // 暖かい (물·음식 등이) 따뜻하다
  'd09_25': Icons.whatshot_rounded, // 熱い 뜨겁다
  'd09_26': Icons.icecream_rounded, // 甘い 달다
  'd09_27': Icons.layers_rounded, // 薄い 얇다
  'd09_28': Icons.sentiment_very_satisfied_rounded, // うまい 맛있다
  'd09_29': Icons.hardware_rounded, // 硬い 딱딱하다
  'd09_30': Icons.local_fire_department_rounded, // 辛い 맵다
  'd09_31': Icons.grain_rounded, // 塩辛い 짜다
  'd09_32': Icons.emoji_food_beverage_rounded, // すっぱい 시다
  'd09_33': Icons.ac_unit_rounded, // 冷たい 차갑다
  'd09_34': Icons.sentiment_dissatisfied_rounded, // 苦い 쓰다
  'd09_35': Icons.bubble_chart_rounded, // 柔らかい 부드럽다
  // DAY 10 식생활 ② 음식
  'd10_01': Icons.emoji_food_beverage_rounded, // お茶 차
  'd10_02': Icons.set_meal_rounded, // 牛肉 소고기
  'd10_03': Icons.cake_rounded, // ケーキ 케이크
  'd10_04': Icons.factory_rounded, // 原料 원료
  'd10_05': Icons.rice_bowl_rounded, // ご飯 밥
  'd10_06': Icons.grass_rounded, // 米 쌀
  'd10_07': Icons.kitchen_rounded, // 材料 재료
  'd10_08': Icons.eco_rounded, // サラダ 샐러드
  'd10_09': Icons.breakfast_dining_rounded, // ジャム 잼
  'd10_10': Icons.circle_rounded, // スイカ 수박
  'd10_11': Icons.kebab_dining_rounded, // ステーキ 스테이크
  'd10_12': Icons.restaurant_menu_rounded, // セット 세트
  'd10_13': Icons.fastfood_rounded, // 食べ物 음식
  'd10_14': Icons.spa_rounded, // 玉ねぎ 양파
  'd10_15': Icons.lunch_dining_rounded, // ハンバーグ 햄버그스테이크
  'd10_16': Icons.sports_bar_rounded, // ビール 맥주
  'd10_17': Icons.medication_rounded, // ビタミン 비타민
  'd10_18': Icons.grain_rounded, // 豆 콩
  'd10_19': Icons.soup_kitchen_rounded, // 味噌 된장
  'd10_20': Icons.menu_book_rounded, // メニュー 메뉴
  'd10_21': Icons.eco_rounded, // 野菜 채소
  'd10_22': Icons.restaurant_rounded, // 料理 요리
  'd10_23': Icons.kitchen_rounded, // 冷蔵庫 냉장고
  'd10_24': Icons.wine_bar_rounded, // ワイン 와인
  'd10_25': Icons.content_cut_rounded, // 切る 자르다
  'd10_26': Icons.construction_rounded, // 作る 만들다
  'd10_27': Icons.grain_rounded, // 細かい 잘다
  'd10_28': Icons.remove_rounded, // 少ない 적다
  // DAY 11 학교 ① 공부
  'd11_01': Icons.translate_rounded, // 英語 영어
  'd11_02': Icons.record_voice_over_rounded, // 会話 회화
  'd11_03': Icons.science_rounded, // 科学 과학
  'd11_04': Icons.edit_rounded, // 書き方 쓰는 법
  'd11_05': Icons.assignment_rounded, // 課題 과제
  'd11_06': Icons.description_rounded, // 紙 종이
  'd11_07': Icons.translate_rounded, // 漢字 한자
  'd11_08': Icons.auto_fix_normal_rounded, // 消しゴム 지우개
  'd11_09': Icons.biotech_rounded, // 研究 연구
  'd11_10': Icons.menu_book_rounded, // 国語 국어
  'd11_11': Icons.edit_note_rounded, // 作文 작문
  'd11_12': Icons.quiz_rounded, // 試験 시험
  'd11_13': Icons.menu_book_rounded, // 辞書 사전
  'd11_14': Icons.help_rounded, // 質問 질문
  'd11_15': Icons.calculate_rounded, // 数学 수학
  'd11_16': Icons.co_present_rounded, // 説明 설명
  'd11_17': Icons.horizontal_rule_rounded, // 線 선
  'd11_18': Icons.sports_handball_rounded, // 体育 체육
  'd11_19': Icons.public_rounded, // 地理 지리
  'd11_20': Icons.text_snippet_rounded, // テキスト 텍스트
  'd11_21': Icons.book_rounded, // 日記 일기
  'd11_22': Icons.mic_rounded, // 発音 발음
  'd11_23': Icons.replay_rounded, // 復習 복습
  'd11_24': Icons.spellcheck_rounded, // 文法 문법
  'd11_25': Icons.school_rounded, // 勉強 공부
  'd11_26': Icons.quiz_rounded, // 問題 문제
  'd11_27': Icons.bedtime_rounded, // 夢 꿈
  'd11_28': Icons.visibility_rounded, // 予習 예습
  'd11_29': Icons.history_edu_rounded, // 歴史 역사
  'd11_30': Icons.summarize_rounded, // レポート 리포트
  'd11_31': Icons.fitness_center_rounded, // 練習 연습
  'd11_32': Icons.psychology_rounded, // 覚える 익히다
  'd11_33': Icons.lightbulb_rounded, // 知る 알다
  'd11_34': Icons.send_rounded, // 出す 내다
  'd11_35': Icons.build_rounded, // 直る 고쳐지다
  'd11_36': Icons.error_rounded, // 間違える 잘못하다
  'd11_37': Icons.cloud_off_rounded, // 忘れる 잊다
  'd11_38': Icons.thumb_up_rounded, // 易しい 쉽다
  'd11_39': Icons.account_tree_rounded, // 複雑な 복잡한
  'd11_40': Icons.local_fire_department_rounded, // 一生懸命な 매우 열심인
  'd11_41': Icons.sentiment_neutral_rounded, // うっかり 무심코
  // DAY 12 학교 ② 학교생활
  'd12_01': Icons.account_balance_rounded, // 学部 학부
  'd12_02': Icons.gavel_rounded, // 規則 규칙
  'd12_03': Icons.school_rounded, // 教育 교육
  'd12_04': Icons.person_4_rounded, // 教師 교사
  'd12_05': Icons.meeting_room_rounded, // 教室 교실
  'd12_06': Icons.sports_soccer_rounded, // クラブ 클럽
  'd12_07': Icons.bed_rounded, // 下宿 하숙
  'd12_08': Icons.co_present_rounded, // 講義 강의
  'd12_09': Icons.supervisor_account_rounded, // 校長 교장
  'd12_10': Icons.theater_comedy_rounded, // 講堂 강당
  'd12_11': Icons.child_care_rounded, // 後輩 후배
  'd12_12': Icons.border_color_rounded, // 黒板 칠판
  'd12_13': Icons.class_rounded, // 授業 수업
  'd12_14': Icons.how_to_reg_rounded, // 出席 출석
  'd12_15': Icons.school_rounded, // 小学校 초등학교
  'd12_16': Icons.school_rounded, // 卒業 졸업
  'd12_17': Icons.desk_rounded, // 机 책상
  'd12_18': Icons.local_library_rounded, // 図書館 도서관
  'd12_19': Icons.beach_access_rounded, // 夏休み 여름 방학
  'd12_20': Icons.school_rounded, // 入学 입학
  'd12_21': Icons.notifications_rounded, // ベル 벨
  'd12_22': Icons.directions_run_rounded, // 急ぐ 서두르다
  'd12_23': Icons.verified_rounded, // 受かる (시험에) 합격하다
  'd12_24': Icons.quiz_rounded, // 受ける (시험을) 치다
  'd12_25': Icons.cast_for_education_rounded, // 教える 가르치다
  'd12_26': Icons.keyboard_return_rounded, // 返す 돌려주다
  'd12_27': Icons.output_rounded, // 貸す 빌려주다
  'd12_28': Icons.directions_bus_rounded, // 通う 다니다
  'd12_29': Icons.input_rounded, // 借りる 빌리다
  'd12_30': Icons.yard_rounded, // 育てる 키우다
  'd12_31': Icons.history_edu_rounded, // 習う 배우다
  'd12_32': Icons.notifications_active_rounded, // 鳴る 울리다
  'd12_33': Icons.play_arrow_rounded, // 始まる 시작되다
  'd12_34': Icons.start_rounded, // 始める 시작하다
  'd12_35': Icons.thumb_up_rounded, // 褒める 칭찬하다
  // DAY 13 회사 ① 일
  'd13_01': Icons.lightbulb_rounded, // アイデア 아이디어
  'd13_02': Icons.mic_rounded, // アナウンサー 아나운서
  'd13_03': Icons.work_history_rounded, // アルバイト 아르바이트
  'd13_04': Icons.train_rounded, // 駅員 역무원
  'd13_05': Icons.groups_rounded, // 会議 회의
  'd13_06': Icons.business_rounded, // 会社 회사
  'd13_07': Icons.brush_rounded, // 画家 화가
  'd13_08': Icons.badge_rounded, // 係 담당자
  'd13_09': Icons.menu_book_rounded, // カタログ 카탈로그
  'd13_10': Icons.engineering_rounded, // 技術 기술
  'd13_11': Icons.account_balance_rounded, // 公務員 공무원
  'd13_12': Icons.content_copy_rounded, // コピー 복사
  'd13_13': Icons.draw_rounded, // サイン 사인
  'd13_14': Icons.work_rounded, // 仕事 일
  'd13_15': Icons.business_center_rounded, // 事務所 사무소
  'd13_16': Icons.badge_rounded, // 社員 사원
  'd13_17': Icons.description_rounded, // 書類 서류
  'd13_18': Icons.toggle_on_rounded, // スイッチ 스위치
  'd13_19': Icons.person_pin_rounded, // 店員 점원
  'd13_20': Icons.storefront_rounded, // パート 파트타임
  'd13_21': Icons.local_shipping_rounded, // 配達 배달
  'd13_22': Icons.article_rounded, // パンフレット 팸플릿
  'd13_23': Icons.inbox_rounded, // 引き出し 서랍
  'd13_24': Icons.folder_rounded, // ファイル 파일
  'd13_25': Icons.fax_rounded, // ファックス 팩스
  'd13_26': Icons.mail_rounded, // 封筒 봉투
  'd13_27': Icons.reply_rounded, // 返事 답장
  'd13_28': Icons.image_rounded, // ポスター 포스터
  'd13_29': Icons.translate_rounded, // 翻訳 번역
  'd13_30': Icons.checklist_rounded, // 用意 준비
  'd13_31': Icons.move_to_inbox_rounded, // 受け取る 받다
  'd13_32': Icons.build_rounded, // 直す 고치다
  'd13_33': Icons.local_shipping_rounded, // 運ぶ 나르다
  'd13_34': Icons.push_pin_rounded, // 貼る 붙이다
  'd13_35': Icons.pan_tool_rounded, // 渡す 건네주다
  // DAY 14 회사 ② 사회생활
  'd14_01': Icons.campaign_rounded, // お知らせ 알림
  'd14_02': Icons.swap_horiz_rounded, // 代わりに 대신에
  'd14_03': Icons.event_available_rounded, // 機会 기회
  'd14_04': Icons.emoji_events_rounded, // 競争 경쟁
  'd14_05': Icons.assessment_rounded, // 結果 결과
  'd14_06': Icons.rule_rounded, // 仕方 하는 방법
  'd14_07': Icons.cancel_rounded, // 失敗 실패
  'd14_08': Icons.alarm_off_rounded, // 遅刻 지각
  'd14_09': Icons.stars_rounded, // チャンス 찬스
  'd14_10': Icons.event_rounded, // 都合 형편
  'd14_11': Icons.gps_fixed_rounded, // 目的 목적
  'd14_12': Icons.directions_run_rounded, // 用事 용무
  'd14_13': Icons.help_rounded, // 理由 이유
  'd14_14': Icons.person_off_rounded, // 留守 부재중
  'd14_15': Icons.info_rounded, // 訳 이유
  'd14_16': Icons.check_box_outline_blank_rounded, // 空く 비다
  'd14_17': Icons.drive_file_move_rounded, // 移す (다른 장소로) 옮기다
  'd14_18': Icons.transfer_within_a_station_rounded, // 移る (위치·장소·지위·소속 등이) 바뀌다
  'd14_19': Icons.send_rounded, // 送る 보내다
  'd14_20': Icons.play_circle_rounded, // 行う 행하다
  'd14_21': Icons.stop_circle_rounded, // 終わる 끝나다
  'd14_22': Icons.event_available_rounded, // 決まる 정해지다
  'd14_23': Icons.gavel_rounded, // 決める 정하다
  'd14_24': Icons.search_rounded, // 探す 찾다
  'd14_25': Icons.fast_forward_rounded, // 進む 진행되다
  'd14_26': Icons.task_alt_rounded, // 済む 끝나다
  'd14_27': Icons.badge_rounded, // 勤める 근무하다
  'd14_28': Icons.self_improvement_rounded, // 慣れる 익숙해지다
  'd14_29': Icons.engineering_rounded, // 働く 일하다
  'd14_30': Icons.lock_open_rounded, // 開く 열다
  'd14_31': Icons.add_location_alt_rounded, // 寄る 들르다
  'd14_32': Icons.pending_rounded, // 忙しい 바쁘다
  'd14_33': Icons.sentiment_satisfied_rounded, // 無理な 무리인
  'd14_34': Icons.cancel_rounded, // 簡単な 간단한
  'd14_35': Icons.thumb_up_rounded, // 役に立つ 도움이 되다
  // DAY 15 쇼핑과 경제
  'd15_01': Icons.store_rounded, // 売り場 매장
  'd15_02': Icons.work_history_rounded, // 営業 영업
  'd15_03': Icons.store_mall_directory_rounded, // オープン 오픈
  'd15_04': Icons.payments_rounded, // お釣り 거스름돈
  'd15_05': Icons.diamond_rounded, // お金持ち 부자
  'd15_06': Icons.account_balance_rounded, // 銀行 은행
  'd15_07': Icons.trending_up_rounded, // 経済 경제
  'd15_08': Icons.factory_rounded, // 工業 공업
  'd15_09': Icons.factory_rounded, // 工場 공장
  'd15_10': Icons.flag_rounded, // 国産 국산
  'd15_11': Icons.room_service_rounded, // サービス 서비스
  'd15_12': Icons.precision_manufacturing_rounded, // 産業 산업
  'd15_13': Icons.inventory_2_rounded, // 品物 물건
  'd15_14': Icons.inventory_rounded, // 製品 제품
  'd15_15': Icons.local_offer_rounded, // セール 세일
  'd15_16': Icons.savings_rounded, // 貯金 저금
  'd15_17': Icons.phone_in_talk_rounded, // 電話代 전화 요금
  'd15_18': Icons.flag_rounded, // 日本製 일본 제품
  'd15_19': Icons.sell_rounded, // 値段 가격
  'd15_20': Icons.agriculture_rounded, // 農業 농업
  'd15_21': Icons.storefront_rounded, // 売店 매점
  'd15_22': Icons.shopping_bag_rounded, // 袋 봉투
  'd15_23': Icons.store_rounded, // 店 가게
  'd15_24': Icons.money_off_rounded, // 無料 무료
  'd15_25': Icons.receipt_rounded, // 料金 요금
  'd15_26': Icons.point_of_sale_rounded, // レジ 레지스터
  'd15_27': Icons.discount_rounded, // 割引 할인
  'd15_28': Icons.input_rounded, // 入れる 넣다
  'd15_29': Icons.sell_rounded, // 売る 팔다
  'd15_30': Icons.checklist_rounded, // 選ぶ 선택하다
  'd15_31': Icons.shopping_cart_rounded, // 買う 사다
  'd15_32': Icons.lock_rounded, // 閉まる 닫히다
  'd15_33': Icons.payment_rounded, // 払う 지불하다
  'd15_34': Icons.visibility_rounded, // 見せる 보여주다
  'd15_35': Icons.money_off_rounded, // 安い 싸다
  // DAY 16 정보통신과 매스컴
  'd16_01': Icons.movie_rounded, // アニメ 애니메이션
  'd16_02': Icons.comment_rounded, // 意見 의견
  'd16_03': Icons.translate_rounded, // 意味 의미
  'd16_04': Icons.language_rounded, // インターネット 인터넷
  'd16_05': Icons.memory_rounded, // 機械 기계
  'd16_06': Icons.mail_rounded, // 切手 우표
  'd16_07': Icons.smartphone_rounded, // 携帯 휴대폰
  'd16_08': Icons.computer_rounded, // コンピューター 컴퓨터
  'd16_09': Icons.text_fields_rounded, // 字 글씨
  'd16_10': Icons.info_rounded, // 情報 정보
  'd16_11': Icons.newspaper_rounded, // 新聞 신문
  'd16_12': Icons.smartphone_rounded, // スマホ 스마트폰
  'd16_13': Icons.school_rounded, // 専門 전문
  'd16_14': Icons.cancel_rounded, // 中止 중지
  'd16_15': Icons.mail_rounded, // 手紙 편지
  'd16_16': Icons.live_tv_rounded, // ドラマ 드라마
  'd16_17': Icons.feed_rounded, // ニュース 뉴스
  'd16_18': Icons.laptop_rounded, // パソコン 퍼스널 컴퓨터
  'd16_19': Icons.tv_rounded, // 番組 프로그램
  'd16_20': Icons.article_rounded, // 文 글
  'd16_21': Icons.podcasts_rounded, // 放送 방송
  'd16_22': Icons.email_rounded, // メール 이메일
  'd16_23': Icons.contact_phone_rounded, // 連絡 연락
  'd16_24': Icons.search_rounded, // 調べる 조사하다
  'd16_25': Icons.fact_check_rounded, // 確かめる 확인하다
  'd16_26': Icons.campaign_rounded, // 伝える 알리다
  'd16_27': Icons.linear_scale_rounded, // 続く 이어지다
  'd16_28': Icons.repeat_rounded, // 続ける 계속하다
  'd16_29': Icons.link_rounded, // つながる 연결되다
  'd16_30': Icons.local_shipping_rounded, // 届く 도착하다
  'd16_31': Icons.send_rounded, // 届ける 보내다
  'd16_32': Icons.sentiment_neutral_rounded, // つまらない 시시하다
  'd16_33': Icons.check_circle_rounded, // 正しい 바르다
  // DAY 17 사건·사고
  'd17_01': Icons.local_fire_department_rounded, // 火事 화재
  'd17_02': Icons.propane_rounded, // ガス 가스
  'd17_03': Icons.error_rounded, // ミス 과실
  'd17_04': Icons.local_police_rounded, // 警察 경찰(관)
  'd17_05': Icons.help_center_rounded, // 原因 원인
  'd17_06': Icons.sports_kabaddi_rounded, // 喧嘩 싸움
  'd17_07': Icons.build_rounded, // 故障 고장
  'd17_08': Icons.car_crash_rounded, // 事故 사고
  'd17_09': Icons.vibration_rounded, // 地震 지진
  'd17_10': Icons.block_rounded, // 邪魔 방해
  'd17_11': Icons.military_tech_rounded, // 戦争 전쟁
  'd17_12': Icons.person_search_rounded, // 泥棒 도둑
  'd17_13': Icons.mood_bad_rounded, // いじめる 괴롭히다
  'd17_14': Icons.sports_mma_rounded, // 打つ 때리다
  'd17_15': Icons.arrow_downward_rounded, // 落ちる 떨어지다
  'd17_16': Icons.south_rounded, // 落とす 떨어뜨리다
  'd17_17': Icons.heart_broken_rounded, // 壊す 부수다
  'd17_18': Icons.broken_image_rounded, // 壊れる 부서지다
  'd17_19': Icons.sentiment_very_dissatisfied_rounded, // 死ぬ 죽다
  'd17_20': Icons.downhill_skiing_rounded, // 滑る 미끄러지다
  'd17_21': Icons.back_hand_rounded, // 捕まえる 잡다
  'd17_22': Icons.search_off_rounded, // 無くす 잃다
  'd17_23': Icons.do_not_disturb_on_rounded, // 無くなる 없어지다
  'd17_24': Icons.sentiment_very_dissatisfied_rounded, // 亡くなる 죽다
  'd17_25': Icons.directions_run_rounded, // 逃げる 도망가다
  'd17_26': Icons.back_hand_rounded, // 盗む 훔치다
  'd17_27': Icons.car_crash_rounded, // ぶつかる 부딪치다
  'd17_28': Icons.sports_mma_rounded, // ぶつける 부딪다
  'd17_29': Icons.broken_image_rounded, // 割る 깨다
  'd17_30': Icons.broken_image_rounded, // 割れる 깨지다
  'd17_31': Icons.flash_on_rounded, // 起こる 일어나다
  'd17_32': Icons.personal_injury_rounded, // 倒れる 쓰러지다
  'd17_33': Icons.do_not_step_rounded, // 踏む 밟다
  'd17_34': Icons.dangerous_rounded, // 危ない 위험하다
  'd17_35': Icons.warning_rounded, // 危険な 위험한
  // DAY 18 국제사회와 공연 문화
  'd18_01': Icons.public_rounded, // アジア 아시아
  'd18_02': Icons.flight_land_rounded, // 帰国 귀국
  'd18_03': Icons.public_rounded, // 国際 국제
  'd18_04': Icons.groups_rounded, // 国民 국민
  'd18_05': Icons.groups_rounded, // 市民 시민
  'd18_06': Icons.location_city_rounded, // 社会 사회
  'd18_07': Icons.diversity_1_rounded, // 人口 인구
  'd18_08': Icons.factory_rounded, // 生産 생산
  'd18_09': Icons.account_balance_rounded, // 政治 정치
  'd18_10': Icons.castle_rounded, // 西洋 서양
  'd18_11': Icons.public_rounded, // 世界 세계
  'd18_12': Icons.oil_barrel_rounded, // 石油 석유
  'd18_13': Icons.flag_rounded, // 大使館 대사관
  'd18_14': Icons.local_airport_rounded, // 飛行場 비행장
  'd18_15': Icons.sailing_rounded, // 貿易 무역
  'd18_16': Icons.gavel_rounded, // 法律 법률
  'd18_17': Icons.flight_takeoff_rounded, // 輸出 수출
  'd18_18': Icons.flight_land_rounded, // 輸入 수입
  'd18_19': Icons.euro_rounded, // ヨーロッパ 유럽
  'd18_20': Icons.shield_rounded, // 守る 지키다
  'd18_21': Icons.trending_up_rounded, // 盛んな 왕성한
  'd18_22': Icons.support_agent_rounded, // 受付 접수
  'd18_23': Icons.festival_rounded, // お祭り 축제
  'd18_24': Icons.music_note_rounded, // 音楽 음악
  'd18_25': Icons.stadium_rounded, // 会場 회장
  'd18_26': Icons.checkroom_rounded, // 着物 기모노(일본의 전통 의상)
  'd18_27': Icons.music_note_rounded, // コンサート 콘서트
  'd18_28': Icons.how_to_reg_rounded, // 参加 참가
  'd18_29': Icons.temple_buddhist_rounded, // 神社 신사
  'd18_30': Icons.confirmation_number_rounded, // チケット 티켓
  'd18_31': Icons.museum_rounded, // 展覧会 전람회
  'd18_32': Icons.palette_rounded, // 美術 미술
  'd18_33': Icons.theater_comedy_rounded, // 文化 문화
  'd18_34': Icons.compare_arrows_rounded, // 違う 다르다
  'd18_35': Icons.app_registration_rounded, // 申し込む 신청하다
  // DAY 19 교통안전
  'd19_01': Icons.directions_rounded, // 行き方 가는 법
  'd19_02': Icons.drive_eta_rounded, // 運転 운전
  'd19_03': Icons.train_rounded, // 駅 역
  'd19_04': Icons.local_gas_station_rounded, // ガソリン 가솔린
  'd19_05': Icons.train_rounded, // 急行 급행
  'd19_06': Icons.flight_rounded, // 空港 공항
  'd19_07': Icons.traffic_rounded, // 交差点 교차점
  'd19_08': Icons.construction_rounded, // 工事 공사
  'd19_09': Icons.traffic_rounded, // 交通 교통
  'd19_10': Icons.local_police_rounded, // 交番 파출소
  'd19_11': Icons.directions_bike_rounded, // 自転車 자전거
  'd19_12': Icons.directions_car_rounded, // 自動車 자동차
  'd19_13': Icons.subway_rounded, // 地下鉄 지하철
  'd19_14': Icons.map_rounded, // 地図 지도
  'd19_15': Icons.warning_rounded, // 注意 주의
  'd19_16': Icons.local_parking_rounded, // 駐車場 주차장
  'd19_17': Icons.exit_to_app_rounded, // 出口 출구
  'd19_18': Icons.add_road_rounded, // 道路 도로
  'd19_19': Icons.train_rounded, // 特急 특급
  'd19_20': Icons.two_wheeler_rounded, // バイク 오토바이
  'd19_21': Icons.directions_bus_rounded, // バス停 버스 정류장
  'd19_22': Icons.flight_rounded, // 飛行機 비행기
  'd19_23': Icons.directions_boat_rounded, // 船 배
  'd19_24': Icons.touch_app_rounded, // 利用 이용
  'd19_25': Icons.directions_walk_rounded, // 歩く 걷다
  'd19_26': Icons.groups_rounded, // 込む 붐비다
  'd19_27': Icons.crop_free_rounded, // 空く (속이) 비다
  'd19_28': Icons.alt_route_rounded, // 通る 통하다
  'd19_29': Icons.pan_tool_rounded, // 止まる 멈추다
  'd19_30': Icons.front_hand_rounded, // 止める 멈추다
  'd19_31': Icons.transfer_within_a_station_rounded, // 乗り換える 갈아타다
  'd19_32': Icons.directions_car_rounded, // 乗る 타다
  'd19_33': Icons.wrong_location_rounded, // 迷う 길을 잃다
  'd19_34': Icons.loop_rounded, // 回る 돌다
  'd19_35': Icons.health_and_safety_rounded, // 安全な 안전한
  'd19_36': Icons.block_rounded, // 不便な 불편한
  'd19_37': Icons.thumb_up_rounded, // 便利な 편리한
  // DAY 20 여행
  'd20_01': Icons.tour_rounded, // 案内 안내
  'd20_02': Icons.looks_one_rounded, // 一度 한 번
  'd20_03': Icons.landscape_rounded, // 田舎 시골
  'd20_04': Icons.redeem_rounded, // お土産 여행지 등에서 사 오는 선물
  'd20_05': Icons.photo_album_rounded, // 思い出 추억
  'd20_06': Icons.flight_rounded, // 海外 해외
  'd20_07': Icons.edit_calendar_rounded, // 計画 계획
  'd20_08': Icons.military_tech_rounded, // 経験 경험
  'd20_09': Icons.travel_explore_rounded, // 見物 구경
  'd20_10': Icons.lock_open_rounded, // 自由 자유
  'd20_11': Icons.flight_takeoff_rounded, // 出発 출발
  'd20_12': Icons.checklist_rounded, // 準備 준비
  'd20_13': Icons.luggage_rounded, // スーツケース 슈트케이스
  'd20_14': Icons.celebration_rounded, // 楽しみ 즐거움
  'd20_15': Icons.near_me_rounded, // 近く 근처
  'd20_16': Icons.psychology_rounded, // つもり 생각
  'd20_17': Icons.directions_car_rounded, // ドライブ 드라이브
  'd20_18': Icons.luggage_rounded, // 荷物 짐
  'd20_19': Icons.local_florist_rounded, // 花見 꽃구경
  'd20_20': Icons.pool_rounded, // プール 수영장
  'd20_21': Icons.hotel_rounded, // ホテル 호텔
  'd20_22': Icons.anchor_rounded, // 港 항구
  'd20_23': Icons.event_rounded, // 予定 예정
  'd20_24': Icons.event_available_rounded, // 予約 예약
  'd20_25': Icons.cottage_rounded, // 旅館 여관
  'd20_26': Icons.card_travel_rounded, // 旅行 여행
  'd20_27': Icons.weekend_rounded, // 和室 일본식 방
  'd20_28': Icons.hotel_rounded, // 着く 도착하다
  'd20_29': Icons.redeem_rounded, // 包む 싸다
  'd20_30': Icons.bed_rounded, // 泊まる 숙박하다
  'd20_31': Icons.format_list_numbered_rounded, // 並ぶ 늘어서다
  'd20_32': Icons.search_rounded, // 見つかる 발견되다
  'd20_33': Icons.search_off_rounded, // 見つける 발견하다
  'd20_34': Icons.back_hand_rounded, // 持つ 가지다
  'd20_35': Icons.auto_awesome_rounded, // 珍しい 귀하다
  // DAY 21 취미와 운동
  'd21_01': Icons.music_note_rounded, // 歌 노래
  'd21_02': Icons.fitness_center_rounded, // 運動 운동
  'd21_03': Icons.movie_rounded, // 映画 영화
  'd21_04': Icons.nightlife_rounded, // 踊り 춤
  'd21_05': Icons.lightbulb_rounded, // 興味 흥미
  'd21_06': Icons.sports_esports_rounded, // ゲーム 게임
  'd21_07': Icons.sports_score_rounded, // 試合 시합
  'd21_08': Icons.photo_camera_rounded, // 写真 사진
  'd21_09': Icons.sports_kabaddi_rounded, // 柔道 유도
  'd21_10': Icons.interests_rounded, // 趣味 취미
  'd21_11': Icons.auto_stories_rounded, // 小説 소설
  'd21_12': Icons.pool_rounded, // 水泳 수영
  'd21_13': Icons.nightlife_rounded, // ダンス 댄스
  'd21_14': Icons.sports_basketball_rounded, // バスケット 농구
  'd21_15': Icons.sports_volleyball_rounded, // バレーボール 배구
  'd21_16': Icons.menu_book_rounded, // 文学 문학
  'd21_17': Icons.auto_stories_rounded, // 漫画 만화
  'd21_18': Icons.sports_baseball_rounded, // 野球 야구
  'd21_19': Icons.hiking_rounded, // 山登り 등산
  'd21_20': Icons.groups_rounded, // 集まる 모이다
  'd21_21': Icons.collections_rounded, // 集める 모으다
  'd21_22': Icons.mic_rounded, // 歌う 노래 부르다
  'd21_23': Icons.pool_rounded, // 泳ぐ 헤엄치다
  'd21_24': Icons.emoji_events_rounded, // 勝つ 이기다
  'd21_25': Icons.phishing_rounded, // 釣る 낚다
  'd21_26': Icons.sports_handball_rounded, // 投げる 던지다
  'd21_27': Icons.terrain_rounded, // 登る (높은 곳에) 오르다
  'd21_28': Icons.directions_run_rounded, // 走る 달리다
  'd21_29': Icons.piano_rounded, // 弾く (악기를) 치다
  'd21_30': Icons.mood_bad_rounded, // 負ける 지다
  'd21_31': Icons.chrome_reader_mode_rounded, // 読む 읽다
  'd21_32': Icons.fiber_new_rounded, // 新しい 새롭다
  'd21_33': Icons.thumb_up_rounded, // 上手な 잘하는
  'd21_34': Icons.star_rounded, // 有名な 유명한
  // DAY 22 자연과 동물
  'd22_01': Icons.water_rounded, // 池 연못
  'd22_02': Icons.landscape_rounded, // 石 돌
  'd22_03': Icons.agriculture_rounded, // 牛 소
  'd22_04': Icons.bedroom_baby_rounded, // 馬 말
  'd22_05': Icons.water_rounded, // 海 바다
  'd22_06': Icons.park_rounded, // 枝 나뭇가지
  'd22_07': Icons.hearing_rounded, // 音 소리
  'd22_08': Icons.beach_access_rounded, // 海岸 해안
  'd22_09': Icons.grass_rounded, // 草 풀
  'd22_10': Icons.landscape_rounded, // 景色 경치
  'd22_11': Icons.record_voice_over_rounded, // 声 목소리
  'd22_12': Icons.terrain_rounded, // 坂 언덕
  'd22_13': Icons.set_meal_rounded, // 魚 물고기
  'd22_14': Icons.add_road_rounded, // 道 길
  'd22_15': Icons.landscape_rounded, // 島 섬
  'd22_16': Icons.grain_rounded, // 砂 모래
  'd22_17': Icons.pets_rounded, // 動物 동물
  'd22_18': Icons.flutter_dash_rounded, // 鳥 새
  'd22_19': Icons.eco_rounded, // 葉 잎
  'd22_20': Icons.local_florist_rounded, // 花 꽃
  'd22_21': Icons.forest_rounded, // 林 숲
  'd22_22': Icons.local_fire_department_rounded, // 火 불
  'd22_23': Icons.light_mode_rounded, // 光 빛
  'd22_24': Icons.water_rounded, // 湖 호수
  'd22_25': Icons.eco_rounded, // 緑 녹색
  'd22_26': Icons.pest_control_rounded, // 虫 벌레
  'd22_27': Icons.forest_rounded, // 森 숲
  'd22_28': Icons.hiking_rounded, // 山道 산길
  'd22_29': Icons.yard_rounded, // 植える 심다
  'd22_30': Icons.content_cut_rounded, // 折る 꺾다
  'd22_31': Icons.visibility_rounded, // 見える 보이다
  'd22_32': Icons.water_drop_rounded, // 浅い 얕다
  'd22_33': Icons.auto_awesome_rounded, // 美しい 아름답다
  'd22_34': Icons.water_rounded, // 深い 깊다
  // DAY 23 계절과 날씨
  'd23_01': Icons.eco_rounded, // 秋 가을
  'd23_02': Icons.ac_unit_rounded, // エアコン 에어컨
  'd23_03': Icons.air_rounded, // 風 바람
  'd23_04': Icons.date_range_rounded, // 季節 계절
  'd23_05': Icons.air_rounded, // 空気 공기
  'd23_06': Icons.cloud_rounded, // 雲 구름
  'd23_07': Icons.ac_unit_rounded, // 氷 얼음
  'd23_08': Icons.wb_cloudy_rounded, // 空 하늘
  'd23_09': Icons.storm_rounded, // 台風 태풍
  'd23_10': Icons.heat_pump_rounded, // 暖房 난방
  'd23_11': Icons.dark_mode_rounded, // 月 달
  'd23_12': Icons.wb_sunny_rounded, // 天気 날씨
  'd23_13': Icons.thermostat_rounded, // 天気予報 일기 예보
  'd23_14': Icons.thermostat_rounded, // 度 도
  'd23_15': Icons.beach_access_rounded, // 夏 여름
  'd23_16': Icons.help_rounded, // 場合 경우
  'd23_17': Icons.local_florist_rounded, // 春 봄
  'd23_18': Icons.wb_sunny_rounded, // 日 해
  'd23_19': Icons.ac_unit_rounded, // 冬 겨울
  'd23_20': Icons.star_rounded, // 星 별
  'd23_21': Icons.ac_unit_rounded, // 雪 눈
  'd23_22': Icons.mode_fan_off_rounded, // 冷房 냉방
  'd23_23': Icons.content_cut_rounded, // 折れる 꺾이다
  'd23_24': Icons.dry_rounded, // 乾く 마르다
  'd23_25': Icons.compare_rounded, // 比べる 비교하다
  'd23_26': Icons.nights_stay_rounded, // 暮れる 날이 저물다
  'd23_27': Icons.beach_access_rounded, // 差す (우산을) 쓰다
  'd23_28': Icons.water_drop_rounded, // 濡れる 젖다
  'd23_29': Icons.air_rounded, // 吹く (바람이) 불다
  'd23_30': Icons.umbrella_rounded, // 止む (비가) 그치다
  'd23_31': Icons.vibration_rounded, // 揺れる 흔들리다
  'd23_32': Icons.wb_sunny_rounded, // 暑い 덥다
  'd23_33': Icons.ac_unit_rounded, // 寒い 춥다
  'd23_34': Icons.air_rounded, // 涼しい 시원하다
  'd23_35': Icons.fitness_center_rounded, // 強い 세다
  // DAY 24 몸
  'd24_01': Icons.directions_walk_rounded, // 足 다리
  'd24_02': Icons.face_rounded, // 頭 머리
  'd24_03': Icons.sports_gymnastics_rounded, // 腕 팔
  'd24_04': Icons.face_rounded, // 顔 얼굴
  'd24_05': Icons.face_retouching_natural_rounded, // 髪 머리털
  'd24_06': Icons.accessibility_rounded, // 体 몸
  'd24_07': Icons.accessibility_new_rounded, // 首 목
  'd24_08': Icons.health_and_safety_rounded, // 健康 건강
  'd24_09': Icons.directions_run_rounded, // ジョギング 조깅
  'd24_10': Icons.accessibility_rounded, // 背中 등
  'd24_11': Icons.bloodtype_rounded, // 血 피
  'd24_12': Icons.back_hand_rounded, // 手 손
  'd24_13': Icons.record_voice_over_rounded, // 喉 목
  'd24_14': Icons.medical_services_rounded, // 歯 이
  'd24_15': Icons.medical_services_rounded, // 歯医者 치과 의사
  'd24_16': Icons.face_6_rounded, // 髭 수염
  'd24_17': Icons.accessibility_rounded, // 身 몸
  'd24_18': Icons.hearing_rounded, // 耳 귀
  'd24_19': Icons.visibility_rounded, // 目 눈
  'd24_20': Icons.wash_rounded, // 洗う 씻다
  'd24_21': Icons.directions_run_rounded, // 動く 움직이다
  'd24_22': Icons.arrow_downward_rounded, // 下がる (열이) 내리다
  'd24_23': Icons.fastfood_rounded, // 太る 살찌다
  'd24_24': Icons.brush_rounded, // 磨く 닦다
  'd24_25': Icons.monitor_weight_rounded, // 痩せる 마르다
  'd24_26': Icons.sick_rounded, // 痛い 아프다
  'd24_27': Icons.battery_1_bar_rounded, // 弱い 약하다
  'd24_28': Icons.sentiment_very_satisfied_rounded, // 元気な 건강한
  // DAY 25 건강
  'd25_01': Icons.fitness_center_rounded, // 力 힘
  'd25_02': Icons.thermostat_rounded, // 熱 열
  'd25_03': Icons.liquor_rounded, // アルコール 알코올
  'd25_04': Icons.biotech_rounded, // 医学 의학
  'd25_05': Icons.medical_services_rounded, // 医者 의사
  'd25_06': Icons.restaurant_rounded, // お腹・腹 배
  'd25_07': Icons.local_florist_rounded, // お見舞い 병문안
  'd25_08': Icons.sick_rounded, // 風邪 감기
  'd25_09': Icons.medical_information_rounded, // 看護師 간호사
  'd25_10': Icons.favorite_rounded, // 気 마음
  'd25_11': Icons.healing_rounded, // 傷 상처
  'd25_12': Icons.smoke_free_rounded, // 禁煙 금연
  'd25_13': Icons.monitor_heart_rounded, // 具合 상태
  'd25_14': Icons.medication_rounded, // 薬 약
  'd25_15': Icons.local_pharmacy_rounded, // 薬屋 약국
  'd25_16': Icons.personal_injury_rounded, // 怪我 부상
  'd25_17': Icons.directions_walk_rounded, // 散歩 산책
  'd25_18': Icons.psychology_rounded, // ストレス 스트레스
  'd25_19': Icons.exit_to_app_rounded, // 退院 퇴원
  'd25_20': Icons.monitor_weight_rounded, // ダイエット 다이어트
  'd25_21': Icons.vaccines_rounded, // 注射 주사
  'd25_22': Icons.local_hotel_rounded, // 入院 입원
  'd25_23': Icons.local_hospital_rounded, // 病院 병원
  'd25_24': Icons.sick_rounded, // 病気 병
  'd25_25': Icons.touch_app_rounded, // 指 손가락
  'd25_26': Icons.arrow_upward_rounded, // 上がる 위로 오르다
  'd25_27': Icons.favorite_rounded, // 生きる 살다
  'd25_28': Icons.touch_app_rounded, // 触る 만지다
  'd25_29': Icons.back_hand_rounded, // 取る 취하다
  'd25_30': Icons.healing_rounded, // 治る 병이 낫다
  'd25_31': Icons.bedtime_rounded, // 眠る 잠자다
  'd25_32': Icons.hotel_rounded, // 寝る 자다
  'd25_33': Icons.block_rounded, // やめる (일 등을) 그만두다
  'd25_34': Icons.snooze_rounded, // 眠い 졸리다
  'd25_35': Icons.priority_high_rounded, // 必要な 필요한
  // DAY 26 시간과 거리
  'd26_01': Icons.history_rounded, // 以前 이전
  'd26_02': Icons.date_range_rounded, // 一週間 일주일간
  'd26_03': Icons.celebration_rounded, // お正月 설
  'd26_04': Icons.wb_twilight_rounded, // 今朝 오늘 아침
  'd26_05': Icons.schedule_rounded, // 午後 오후
  'd26_06': Icons.today_rounded, // 今年 올해
  'd26_07': Icons.history_rounded, // この間 지난번
  'd26_08': Icons.next_plan_rounded, // 今度 이번
  'd26_09': Icons.nights_stay_rounded, // 今夜・今晩 오늘 밤
  'd26_10': Icons.update_rounded, // 最近 최근
  'd26_11': Icons.first_page_rounded, // 最初 최초
  'd26_12': Icons.history_edu_rounded, // 時代 시대
  'd26_13': Icons.trending_up_rounded, // 将来 장래
  'd26_14': Icons.more_horiz_rounded, // 途中 도중
  'd26_15': Icons.calendar_month_rounded, // 月 한 달
  'd26_16': Icons.lunch_dining_rounded, // 昼休み 점심시간
  'd26_17': Icons.wb_sunny_rounded, // 毎朝 매일 아침
  'd26_18': Icons.history_toggle_off_rounded, // 昔 옛날
  'd26_19': Icons.straighten_rounded, // メートル 미터
  'd26_20': Icons.wb_twilight_rounded, // 夕方 저물녘
  'd26_21': Icons.calendar_view_week_rounded, // 曜日 요일
  'd26_22': Icons.event_note_rounded, // 来週 다음 주
  'd26_23': Icons.running_with_errors_rounded, // 遅れる 늦다
  'd26_24': Icons.hourglass_bottom_rounded, // かかる 걸리다
  'd26_25': Icons.alarm_on_rounded, // 間に合う 시간에 늦지 않게 대다
  'd26_26': Icons.near_me_rounded, // 近い 가깝다
  'd26_27': Icons.social_distance_rounded, // 遠い 멀다
  'd26_28': Icons.fast_forward_rounded, // 早い 이르다
  'd26_29': Icons.history_rounded, // さっき 아까
  'd26_30': Icons.hourglass_top_rounded, // しばらく 잠시
  'd26_31': Icons.all_inclusive_rounded, // ずっと 쭉
  'd26_32': Icons.alarm_rounded, // そろそろ 이제
  'd26_33': Icons.repeat_one_rounded, // たまに 가끔
  'd26_34': Icons.looks_one_rounded, // まず 우선
  'd26_35': Icons.hourglass_bottom_rounded, // もうすぐ 이제 곧
  // DAY 27 방향·위치
  'd27_01': Icons.compare_arrows_rounded, // 間 사이
  'd27_02': Icons.do_not_disturb_on_rounded, // 以外 이외
  'd27_03': Icons.expand_less_rounded, // 以上 이상
  'd27_04': Icons.vertical_align_center_rounded, // 以内 이내
  'd27_05': Icons.inbox_rounded, // 内 안
  'd27_06': Icons.flip_to_back_rounded, // 裏 뒤
  'd27_07': Icons.flip_to_front_rounded, // 表 겉
  'd27_08': Icons.near_me_rounded, // 近所 근처
  'd27_09': Icons.map_rounded, // 区 구(지역)
  'd27_10': Icons.map_rounded, // 県 현(일본의 행정 구역)
  'd27_11': Icons.nature_people_rounded, // 郊外 교외
  'd27_12': Icons.location_city_rounded, // 市 시
  'd27_13': Icons.home_rounded, // 住所 주소
  'd27_14': Icons.crop_free_rounded, // 隅 구석
  'd27_15': Icons.event_seat_rounded, // 席 자리
  'd27_16': Icons.account_balance_rounded, // 都 도
  'd27_17': Icons.location_city_rounded, // 東京 도쿄
  'd27_18': Icons.west_rounded, // 西 서쪽
  'd27_19': Icons.place_rounded, // 場所 장소
  'd27_20': Icons.threesixty_rounded, // 周り 주위
  'd27_21': Icons.filter_center_focus_rounded, // 真ん中 한가운데
  'd27_22': Icons.compare_arrows_rounded, // 両方 양쪽
  'd27_23': Icons.open_with_rounded, // 押す 밀다
  'd27_24': Icons.keyboard_return_rounded, // 帰る 돌아가다
  'd27_25': Icons.directions_walk_rounded, // 来る 오다
  'd27_26': Icons.arrow_downward_rounded, // 下げる 내리다
  'd27_27': Icons.arrow_upward_rounded, // 上る・上がる 오르다
  'd27_28': Icons.open_in_new_rounded, // 引く 당기다
  'd27_29': Icons.navigation_rounded, // 向かう 향하다
  'd27_30': Icons.undo_rounded, // 戻る 되돌아가다
  'd27_31': Icons.attach_money_rounded, // 高い 비싸다
  'd27_32': Icons.speed_rounded, // 速い 빠르다
  'd27_33': Icons.low_priority_rounded, // 低い 낮다
  'd27_34': Icons.straight_rounded, // まっすぐ 똑바로
  'd27_35': Icons.more_horiz_rounded, // ～おきに ~걸러
  // DAY 28 수·양·정도
  'd28_01': Icons.expand_more_rounded, // 以下 이하
  'd28_02': Icons.house_rounded, // 軒 채(집을 세는 단위)
  'd28_03': Icons.groups_rounded, // 大勢 여럿
  'd28_04': Icons.trending_up_rounded, // オーバー 오버
  'd28_05': Icons.directions_car_rounded, // 二台 두 대
  'd28_06': Icons.looks_two_rounded, // 二倍 두 배
  'd28_07': Icons.cake_rounded, // 二十歳 스무 살
  'd28_08': Icons.repeat_rounded, // 毎回 매회
  'd28_09': Icons.close_rounded, // 掛ける 곱하다
  'd28_10': Icons.calculate_rounded, // 数える 수를 세다
  'd28_11': Icons.add_rounded, // 足す 더하다
  'd28_12': Icons.add_task_rounded, // 足りる 충분하다
  'd28_13': Icons.trending_up_rounded, // 増える 늘다
  'd28_14': Icons.trending_down_rounded, // 減る 줄다
  'd28_15': Icons.group_add_rounded, // 多い 많다
  'd28_16': Icons.sentiment_dissatisfied_rounded, // 惜しい 아깝다
  'd28_17': Icons.air_rounded, // 軽い 가볍다
  'd28_18': Icons.check_circle_rounded, // 十分な 충분한
  'd28_19': Icons.tune_rounded, // 適当な 적당한
  'd28_20': Icons.remove_circle_outline_rounded, // あまり 그다지
  'd28_21': Icons.format_list_bulleted_rounded, // いっぱい 많이
  'd28_22': Icons.remove_rounded, // 少し 조금
  'd28_23': Icons.sentiment_very_satisfied_rounded, // にこにこ 생글생글
  'd28_24': Icons.not_interested_rounded, // 二度と 두 번 다시(부정 수반)
  'd28_25': Icons.tune_rounded, // 程 정도
  'd28_26': Icons.emoji_events_rounded, // 最も 가장
  'd28_27': Icons.percent_rounded, // 割合に 비교적
  // DAY 29 부사
  'd29_01': Icons.all_inclusive_rounded, // いくら～ても 아무리 ~해도
  'd29_02': Icons.loop_rounded, // いつも 항상
  'd29_03': Icons.task_alt_rounded, // 必ず 반드시
  'd29_04': Icons.flash_on_rounded, // 急に 갑자기
  'd29_05': Icons.bedtime_rounded, // ぐっすり 푹(깊은 잠을 자는 모양)
  'd29_06': Icons.block_rounded, // 決して 결코(부정 수반)
  'd29_07': Icons.check_circle_outline_rounded, // 十分 충분히
  'd29_08': Icons.trending_up_rounded, // ずいぶん 매우
  'd29_09': Icons.done_all_rounded, // すっかり 완전히
  'd29_10': Icons.priority_high_rounded, // ぜひ 꼭
  'd29_11': Icons.not_interested_rounded, // 全然 전혀(부정 수반)
  'd29_12': Icons.arrow_forward_rounded, // そう 그렇게
  'd29_13': Icons.remove_rounded, // それほど 그다지
  'd29_14': Icons.remove_circle_outline_rounded, // そんなに 그다지(부정 수반)
  'd29_15': Icons.pie_chart_rounded, // 大体 대개
  'd29_16': Icons.trending_up_rounded, // だいぶ 상당히
  'd29_17': Icons.priority_high_rounded, // 大変 매우
  'd29_18': Icons.verified_rounded, // 確か 분명히
  'd29_19': Icons.psychology_alt_rounded, // たぶん 아마도
  'd29_20': Icons.stairs_rounded, // だんだん 점점
  'd29_21': Icons.do_not_disturb_alt_rounded, // ちっとも 조금도(부정 수반)
  'd29_22': Icons.check_circle_rounded, // ちょうど 마침
  'd29_23': Icons.fitness_center_rounded, // できるだけ 가능한 한
  'd29_24': Icons.sports_score_rounded, // とうとう 드디어
  'd29_25': Icons.star_rounded, // 特別に 특별히
  'd29_26': Icons.fast_forward_rounded, // どんどん 점점
  'd29_27': Icons.hourglass_empty_rounded, // なかなか 좀처럼(부정 수반)
  'd29_28': Icons.thumbs_up_down_rounded, // なるべく 가능한 한 ~하도록
  'd29_29': Icons.replay_rounded, // 何度も 몇 번이나
  'd29_30': Icons.lens_blur_rounded, // はっきり 확실히
  'd29_31': Icons.bolt_rounded, // 非常に 대단히
  'd29_32': Icons.remove_rounded, // 別に 특별히
  'd29_33': Icons.timelapse_rounded, // ほとんど 거의(부정 수반)
  'd29_34': Icons.verified_rounded, // 本当に 정말로
  'd29_35': Icons.help_rounded, // もし 만약
  'd29_36': Icons.task_alt_rounded, // もちろん 물론
  'd29_37': Icons.add_circle_rounded, // もっと 좀 더
  'd29_38': Icons.sentiment_satisfied_rounded, // やっと 겨우
  'd29_39': Icons.done_all_rounded, // やはり 역시
  'd29_40': Icons.slow_motion_video_rounded, // ゆっくり 천천히
  'd29_41': Icons.repeat_rounded, // よく 자주
  // DAY 30 경어와 접속어
  'd30_01': Icons.work_outline_rounded, // なさる 하시다
  'd30_02': Icons.directions_walk_rounded, // いらっしゃる 가시다
  'd30_03': Icons.record_voice_over_rounded, // おっしゃる 말씀하시다
  'd30_04': Icons.visibility_rounded, // ご覧になる 보시다
  'd30_05': Icons.restaurant_rounded, // 召し上がる 드시다
  'd30_06': Icons.psychology_rounded, // ご存じだ 알고 계시다
  'd30_07': Icons.door_front_door_rounded, // おいでになる 오시다
  'd30_08': Icons.card_giftcard_rounded, // くださる 주시다
  'd30_09': Icons.person_pin_circle_rounded, // ～ていらっしゃる ~하고 계시다
  'd30_10': Icons.help_outline_rounded, // 伺う 여쭙다
  'd30_11': Icons.visibility_rounded, // 拝見する (겸양) 보다
  'd30_12': Icons.work_rounded, // 致す 하다
  'd30_13': Icons.person_pin_circle_rounded, // おる 있다
  'd30_14': Icons.hourglass_empty_rounded, // ～ておる ~하고 있다
  'd30_15': Icons.directions_walk_rounded, // 参る 가다
  'd30_16': Icons.record_voice_over_rounded, // 申す 말하다
  'd30_17': Icons.handshake_rounded, // お目にかかる 만나 뵙다
  'd30_18': Icons.card_giftcard_rounded, // 差し上げる 드리다
  'd30_19': Icons.move_to_inbox_rounded, // いただく 받다
  'd30_20': Icons.inventory_2_rounded, // ございます 있습니다
  'd30_21': Icons.chat_rounded, // ～でございます ~입니다
  'd30_22': Icons.compare_arrows_rounded, // けれど 하지만
  'd30_23': Icons.compare_arrows_rounded, // けれども 그렇지만
  'd30_24': Icons.compare_arrows_rounded, // しかし 그러나
  'd30_25': Icons.arrow_forward_rounded, // すると 그러자
  'd30_26': Icons.redo_rounded, // それから 그리고 나서
  'd30_27': Icons.arrow_forward_rounded, // それで 그래서
  'd30_28': Icons.add_circle_outline_rounded, // それに 게다가
  'd30_29': Icons.arrow_forward_rounded, // だから 그러니까
  'd30_30': Icons.swap_horiz_rounded, // ところが 그런데
  'd30_31': Icons.swap_calls_rounded, // ところで (화제 전환) 그런데
  'd30_32': Icons.lightbulb_rounded, // なるほど 역시
  'd30_33': Icons.call_split_rounded, // または 또는
};
