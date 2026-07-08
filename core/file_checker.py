from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS

def _count_gps(deg, min, sec):
    result = float(deg) + (float(min) / 60) + (float(sec) / 3600)
    return result

def extract_image_metadata(file_path):
    result = { "status":"processing", "has_exif": False, "error_message": "", "hardware": {}, "software": {}, "gps": {} }
    try:
        with Image.open(file_path) as img:
            raw_exif = img.getexif()
            print(raw_exif)
            if raw_exif:
                result["has_exif"] = True
                raw_gps_info = None
                for tag_id, value in raw_exif.items():
                    tag_name = TAGS.get(tag_id)
                    if tag_name == "Make" or tag_name == "Model":
                        result["hardware"][tag_name] = value
                    elif tag_name == "DateTime" or tag_name == "Software":
                        result["software"][tag_name] = value
                    elif tag_name == "GPSInfo":
                        if isinstance(value, int):
                            raw_gps_info = raw_exif.get_ifd(tag_id)
                        else:
                            raw_gps_info = value
                
                if raw_gps_info:
                    print(raw_gps_info)
                    gps_clean_data = {}
                    for gps_tag_id, value in raw_gps_info.items():
                        tag_name = GPSTAGS.get(gps_tag_id)
                        gps_clean_data[tag_name] = value
                    
                    gps_latitude = gps_clean_data.get("GPSLatitude")
                    gps_latitude_ref = gps_clean_data.get("GPSLatitudeRef")
                    gps_longitude = gps_clean_data.get("GPSLongitude")
                    gps_longitude_ref = gps_clean_data.get("GPSLongitudeRef")
                    
                    if gps_latitude and gps_longitude and gps_latitude_ref and gps_longitude_ref:
                        try:
                            latitude = _count_gps(gps_latitude[0], gps_latitude[1], gps_latitude[2])
                            if gps_latitude_ref == 'S':
                                latitude *= -1
                            longitude = _count_gps(gps_longitude[0], gps_longitude[1], gps_longitude[2])
                            if gps_longitude_ref == 'W':
                                longitude *= -1
                            result["gps"]["latitude"] = round(latitude, 6)
                            result["gps"]["longitude"] = round(longitude, 6)
                        except:
                            pass
    except Exception as e:   
        result["error_message"] = str(e)
        result["status"] = "error"
        print(result)
        return result
    result["status"] = "success"
    print(result)
    return result
