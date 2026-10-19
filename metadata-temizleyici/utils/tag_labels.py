from __future__ import annotations

HIGH_RISK_TAGS = frozenset(
    {
        "GPSLatitude",
        "GPSLongitude",
        "GPSAltitude",
        "GPSPosition",
        "GPSDateStamp",
        "GPSTimeStamp",
        "GPSLatitudeRef",
        "GPSLongitudeRef",
        "GPSAltitudeRef",
        "GPSImgDirection",
        "GPSDestLatitude",
        "GPSDestLongitude",
        "SerialNumber",
        "BodySerialNumber",
        "LensSerialNumber",
        "OwnerName",
        "Artist",
        "Copyright",
        "UserComment",
        "ImageDescription",
    }
)

TAG_LABELS_TR: dict[str, str] = {
    "Make": "Üretici",
    "Model": "Model",
    "DateTimeOriginal": "Çekim tarihi",
    "DateTime": "Değiştirilme tarihi",
    "Software": "Yazılım",
    "GPSLatitude": "GPS enlem",
    "GPSLongitude": "GPS boylam",
    "GPSAltitude": "GPS yükseklik",
    "GPSPosition": "GPS konum",
    "SerialNumber": "Seri numarası",
    "Artist": "Sanatçı / sahip",
    "OwnerName": "Sahip adı",
    "UserComment": "Kullanıcı yorumu",
    "ImageDescription": "Açıklama",
    "Orientation": "Yönelim",
    "ExposureTime": "Pozlama süresi",
    "FNumber": "Diyafram",
    "ISOSpeedRatings": "ISO",
    "FocalLength": "Odak uzaklığı",
    "LensModel": "Lens modeli",
    "Flash": "Flaş",
    "WhiteBalance": "Beyaz dengesi",
}


def tag_label(name: str) -> str:
    return TAG_LABELS_TR.get(name, name)


def risk_level(name: str) -> str:
    if name in HIGH_RISK_TAGS or name.startswith("GPS"):
        return "high"
    return "low"


def risk_label(level: str) -> str:
    return "Yüksek" if level == "high" else "Düşük"
