extends RefCounted

## 승패 연출 전용 표정 — 캐릭터마다 **장면별로 따로 쓸 얼굴 그림**(2026-10-11 사용자 요청).
## 칸이 비어 있거나 그림이 없으면 원래 고르던 얼굴(리그의 액션·피격·올라잇 얼굴)을 그대로 쓴다.
## **그림이 생기면 아래 경로만 채우면 된다**(장면 코드는 안 건드려도 됨).
## 칸:
##  win           승리 화면 클로즈업
##  lose          패배 화면 클로즈업
##  arrest_happy  연행 장면 — 승자가 "이겼다!" 하고 신나 있는 동안(풀 죽기 전)
##  arrest_sad    연행 장면 — 끌려가는 동안(패자는 내내, 승자는 풀 죽은 뒤)
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — preload로 쓴다

const FACES := {
	"일진": {
		"win": "res://sprite/일진/신남일진.png",
		"arrest_happy": "res://sprite/일진/신남일진.png",
	},
	# 기분 좋은 표정(2026-10-11 팀원 그림)
	"지하철 아저씨": {
		"win": "res://sprite/지하철빌/환히웃는지하철아저씨.png",
		"arrest_happy": "res://sprite/지하철빌/환히웃는지하철아저씨.png",
	},
	# 할매 똥씹은 표정(2026-10-11 팀원 그림)
	"고양이 아주머니": {"arrest_sad": "res://sprite/고양이 아줌마/시무룩아줌마.png"},
	# ⚠️ 팀 피드백 "애새끼 기분 안 좋은 표정"은 금쪽이가 아니라 **층간소음 아이**였다(팀원 그림 sprite/층간소음/시무룩한아이.png —
	# 아이 머리와 같은 1374x1145 캔버스). 아이는 리그가 아니라 이 표에 안 들어간다 — 어디에 쓸지 정해지면 EndingKid/ArrestKid 쪽에 단다
}

## 그 캐릭터·칸의 얼굴 그림. 없으면 null(원래 얼굴을 쓸 것)
static func face(character_name: String, slot: String) -> Texture2D:
	var slots: Dictionary = FACES.get(character_name, {})
	var path: String = str(slots.get(slot, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
