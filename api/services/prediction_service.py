import numpy as np
from datetime import datetime, timedelta
from repositories.event_repository import EventRepository

class PredictionService:
    def __init__(self, repository: EventRepository):
        self.repository = repository

    def _parse_utc(self, time_str):
        if not time_str: return None
        clean_str = time_str.split('+')[0].replace('Z', '')
        return datetime.fromisoformat(clean_str)

    def _get_max_naps(self, dob_str):
        dob = self._parse_utc(dob_str)
        age_days = (datetime.utcnow() - dob).days
        months = age_days / 30
        if months < 4: return 5
        if months < 6: return 4
        if months < 9: return 3
        if months < 14: return 2
        if months < 36: return 1
        return 0

    def calculate_schedule(self, baby_id: str):
        events = self.repository.get_recent_events(baby_id)
        baby_info = self.repository.get_baby_info(baby_id)
        
        if not events:
            return {"error": "No hay datos suficientes para calcular"}

        morning_ww, evening_ww, day_ww, nap_lengths, wake_hours = [], [], [], [], []
        feed_anchors = []
        
        now_utc = datetime.utcnow()
        cutoff_today = now_utc - timedelta(hours=16) 
        morning_wake_today = None
        last_wake_time = None
        naps_taken_today = 0

        last_wake = None
        is_first_nap_of_day = False

        for ev in events:
            start = self._parse_utc(ev['start_time'])
            end = self._parse_utc(ev['end_time'])
            cat = ev['category']

            if cat == 'woke_up':
                last_wake, is_first_nap_of_day = start, True
                wake_hours.append(start.hour + start.minute/60)
            elif cat == 'nap':
                if last_wake:
                    ww = (start - last_wake).total_seconds() / 60
                    if 60 < ww < 480:
                        (morning_ww if is_first_nap_of_day else day_ww).append(ww)
                if end:
                    nap_lengths.append((end - start).total_seconds() / 60)
                    last_wake, is_first_nap_of_day = end, False
            elif cat == 'bedtime' and last_wake:
                ww = (start - last_wake).total_seconds() / 60
                if 60 < ww < 480: evening_ww.append(ww)
                last_wake = None
            elif cat == 'bottle' or cat == 'nursing':
                feed_anchors.append(start.hour + start.minute/60)

            if start > cutoff_today:
                if cat == 'woke_up':
                    morning_wake_today = start
                    last_wake_time = start
                    naps_taken_today = 0 
                elif cat == 'nap' and end:
                    last_wake_time = end
                    naps_taken_today += 1

        max_naps_allowed = self._get_max_naps(baby_info['dob'])

        defaults = {
            0: (300, 300, 360, 0),    
            1: (270, 300, 330, 120),  
            2: (150, 180, 210, 90),   
            3: (120, 150, 150, 60),   
            4: (90, 120, 120, 45),    
            5: (60, 90, 90, 45),      
        }
        defs = defaults.get(max_naps_allowed, defaults[2])

        def smart_median(user_data, default_val):
            if not user_data: return default_val
            min_val, max_val = default_val * 0.7, default_val * 1.3
            valid_data = [w for w in user_data if min_val <= w <= max_val]
            if not valid_data: return default_val 
            return (np.median(valid_data) + default_val) / 2

        profile = {
            "ww_morning": smart_median(morning_ww, defs[0]),
            "ww_day": smart_median(day_ww, defs[1]),
            "ww_evening": smart_median(evening_ww, defs[2]),
            "nap_base": smart_median(nap_lengths, defs[3]),
            "avg_wake_hour": np.mean(wake_hours) if wake_hours else 7.5,
            "max_naps": max_naps_allowed,
            "feed_anchors": sorted(feed_anchors)
        }

        return self._generate_timeline(profile, morning_wake_today, last_wake_time, naps_taken_today)
    
    def calculate_wake_prediction(self, baby_id: str):
        events = self.repository.get_recent_events(baby_id)
        
        if not events:
            return None

        night_durations = []
        wake_hours = []
        last_bedtime_hist = None

        for ev in events:
            start = self._parse_utc(ev['start_time'])
            cat = ev['category']

            if cat == 'bedtime':
                last_bedtime_hist = start
            elif cat == 'woke_up':
                wake_hours.append(start.hour + start.minute / 60)
                if last_bedtime_hist:
                    dur = (start - last_bedtime_hist).total_seconds() / 60
                    if 480 < dur < 840: 
                        night_durations.append(dur)
                last_bedtime_hist = None

        def smart_median(user_data, default_val):
            if not user_data: return default_val
            min_val, max_val = default_val * 0.7, default_val * 1.3
            valid_data = [w for w in user_data if min_val <= w <= max_val]
            if not valid_data: return default_val
            return (np.median(valid_data) + default_val) / 2

        avg_night_sleep = smart_median(night_durations, 660)
        avg_wake_hour = np.mean(wake_hours) if wake_hours else 7.5

        now_utc = datetime.utcnow()
        cutoff_today = now_utc - timedelta(hours=16)
        active_bedtime = None

        for ev in reversed(events):
            start = self._parse_utc(ev['start_time'])
            if start < cutoff_today:
                break
            if ev['category'] == 'woke_up':
                break
            if ev['category'] == 'bedtime':
                active_bedtime = start
                break

        if not active_bedtime:
            schedule = self.calculate_schedule(baby_id)
            if isinstance(schedule, dict) and "error" in schedule:
                return None
            for item in schedule:
                if item.get("type") == "bedtime":
                    active_bedtime = datetime.strptime(item["start"], '%Y-%m-%dT%H:%M:%SZ')
                    break

        if not active_bedtime: 
            return None

        pure_wake = active_bedtime + timedelta(minutes=avg_night_sleep)

        h, m = int(avg_wake_hour), int((avg_wake_hour % 1) * 60)
        target_wake = active_bedtime.replace(hour=h, minute=m, second=0, microsecond=0)

        if target_wake < active_bedtime:
            target_wake += timedelta(days=1)
        elif target_wake > active_bedtime + timedelta(hours=18):
            target_wake -= timedelta(days=1)

        diff_seconds = (target_wake - pure_wake).total_seconds()
        blend_factor = 0.85 

        final_wake = pure_wake + timedelta(seconds=diff_seconds * blend_factor)

        if final_wake > target_wake + timedelta(minutes=45):
            final_wake = target_wake + timedelta(minutes=45)
        if final_wake < target_wake - timedelta(minutes=45):
            final_wake = target_wake - timedelta(minutes=45)

        return {
            "type": "woke_up",
            "start": final_wake.strftime('%Y-%m-%dT%H:%M:%SZ'),
            "note": "Despertar previsto"
        }

    def _generate_timeline(self, p, morning_wake, last_wake, naps_taken):
        timeline = []
        now_utc = datetime.utcnow()
        
        if morning_wake:
            base_wake = morning_wake
        else:
            h, m = int(p['avg_wake_hour']), int((p['avg_wake_hour'] % 1) * 60)
            base_wake = now_utc.replace(hour=h, minute=m, second=0, microsecond=0)
            if base_wake > now_utc + timedelta(hours=12):
                base_wake -= timedelta(days=1)
            elif base_wake < now_utc - timedelta(hours=12):
                base_wake += timedelta(days=1)
                
        target_bed = base_wake + timedelta(hours=12, minutes=15)
        
        curr = last_wake if last_wake else base_wake
        
        if curr < now_utc - timedelta(hours=18):
            curr = base_wake
            naps_taken = 0
            
        nap_idx = naps_taken + 1
        
        while len(timeline) < 10: 
            if nap_idx > p['max_naps']:
                ww_current = p['ww_evening'] 
                pure_bed = curr + timedelta(minutes=ww_current)
                
                if pure_bed < target_bed - timedelta(minutes=80):
                    next_nap_start = curr + timedelta(minutes=p['ww_day'] * 0.85) 
                    next_nap_end = next_nap_start + timedelta(minutes=30) 
                    
                    timeline.append({
                        "type": "nap",
                        "index": nap_idx,
                        "start": next_nap_start.strftime('%Y-%m-%dT%H:%M:%SZ'),
                        "end": next_nap_end.strftime('%Y-%m-%dT%H:%M:%SZ'),
                        "note": "Siesta de rescate"
                    })
                    curr = next_nap_end
                    nap_idx += 1
                    continue

                diff_seconds = (target_bed - pure_bed).total_seconds()
                
                blend_factor = 0.75 if p['max_naps'] <= 2 else 0.40
                
                final_bed = pure_bed + timedelta(seconds=diff_seconds * blend_factor)
                
                if final_bed > target_bed + timedelta(minutes=60):
                    final_bed = target_bed + timedelta(minutes=60)
                    
                timeline.append({
                    "type": "bedtime", 
                    "start": final_bed.strftime('%Y-%m-%dT%H:%M:%SZ'), 
                    "note": "Hora de dormir"
                })
                break

            ww_current = p['ww_morning'] if nap_idx == 1 else p['ww_day']
            
            if (curr + timedelta(minutes=ww_current)) > (target_bed - timedelta(minutes=120)):
                ww_current = p['ww_evening']
            
            next_nap_start = curr + timedelta(minutes=ww_current)
            
            if next_nap_start >= target_bed - timedelta(minutes=60):
                timeline.append({
                    "type": "bedtime", 
                    "start": next_nap_start.strftime('%Y-%m-%dT%H:%M:%SZ'), 
                    "note": "Cierre día"
                })
                break

            next_nap_end = next_nap_start + timedelta(minutes=p['nap_base'])
            
            timeline.append({
                "type": "nap",
                "index": nap_idx,
                "start": next_nap_start.strftime('%Y-%m-%dT%H:%M:%SZ'),
                "end": next_nap_end.strftime('%Y-%m-%dT%H:%M:%SZ')
            })
            curr = next_nap_end
            nap_idx += 1
            
        return timeline