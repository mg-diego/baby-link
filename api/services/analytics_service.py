from datetime import datetime, date

import pandas as pd
from models.analytics_models import DailySummary
from models.event_models import EventCategory
from repositories.analytics_repository import AnalyticsRepository

class AnalyticsService:
    def __init__(self, repository: AnalyticsRepository):
        self.repository = repository

    def get_events_by_date_range(self, baby_id: str, start_date: date, end_date: date) -> list:
        return self.repository.get_events_by_date_range(baby_id, start_date, end_date)

    def get_daily_summary(self, baby_id: str, target_date: date) -> DailySummary:
        events = self.repository.get_events_by_date_range(baby_id, target_date, target_date)
        
        total_nap = 0
        total_feeds = 0
        total_dirty = 0
        
        for event in events:
            category = event.get("category")
            metadata = event.get("metadata", {})
            
            if category == EventCategory.NAP:
                start_str = event.get("start_time")
                end_str = event.get("end_time")
                if start_str and end_str:
                    start_dt = datetime.fromisoformat(start_str.replace('Z', '+00:00'))
                    end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00'))
                    total_nap += int((end_dt - start_dt).total_seconds() / 60)
                    
            elif category == EventCategory.FEED:
                total_feeds += 1
                
            elif category == EventCategory.DIAPER:
                condition = metadata.get("condition")
                if condition in ["dirty", "mixed"]:
                    total_dirty += 1

        return DailySummary(
            target_date=target_date,
            total_nap_minutes=total_nap,
            total_feeds=total_feeds,
            total_dirty_diapers=total_dirty
        )
    
    def generate_nap_sleep_stats(self, baby_id: str, start_date: str, end_date: str):
        raw_events = self.repository.get_events_by_category(baby_id, "nap", start_date, end_date)
        
        df = pd.DataFrame(raw_events)
        
        if df.empty:
            return {"summary_cards": [], "charts": []}

        df['start_time'] = pd.to_datetime(df['start_time'], format='ISO8601')
        df['end_time'] = pd.to_datetime(df['end_time'], format='ISO8601')
        
        df = df[df['category'] == 'nap'].copy()

        if df.empty:
            return {"summary_cards": [], "charts": []}

        df['duration_hours'] = (df['end_time'] - df['start_time']).dt.total_seconds() / 3600.0
        df['date'] = df['start_time'].dt.strftime('%Y-%m-%d')
        
        df = df.sort_values(['date', 'start_time'])
        df['nap_index'] = df.groupby('date').cumcount() + 1
        df['nap_label'] = 'Siesta ' + df['nap_index'].astype(str)

        date_range = pd.date_range(start=start_date, end=end_date).strftime('%Y-%m-%d')
        
        label_mapping = {}
        for d in date_range:
            dt_obj = pd.to_datetime(d)
            meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
            label_mapping[d] = f"{dt_obj.day} {meses[dt_obj.month - 1]}"
            
        x_labels = list(label_mapping.values())

        total_naps = len(df)
        avg_duration_hours = df['duration_hours'].mean()
        h = int(avg_duration_hours)
        m = int((avg_duration_hours - h) * 60)
        avg_str = f"{h}h {m}m"

        summary_cards = [
            {"label": "Total Siestas", "value": str(total_naps), "trend": None},
            {"label": "Media por Siesta", "value": avg_str, "trend": None}
        ]

        daily_totals = df.groupby('date')['duration_hours'].sum().reindex(date_range, fill_value=0).tolist()

        total_naps_trend = {
            "id": "total_naps_trend",
            "title": "Total de horas dormidas (Siestas)",
            "type": "line",
            "data": {
                "x_labels": x_labels,
                "series": [{"name": "Horas Totales", "data": [round(x, 2) for x in daily_totals]}]
            }
        }

        pivot_evolution = df.pivot(index='date', columns='nap_label', values='duration_hours').reindex(date_range).fillna(0)
        evolution_series = []
        for col in pivot_evolution.columns:
            evolution_series.append({
                "name": col,
                "data": [round(x, 2) for x in pivot_evolution[col].tolist()]
            })

        naps_evolution = {
            "id": "naps_evolution",
            "title": "Evolución por siesta",
            "type": "line_multiple",
            "data": {
                "x_labels": x_labels,
                "series": evolution_series
            }
        }

        nap_sums = df.groupby('nap_label')['duration_hours'].sum()
        total_sum = nap_sums.sum()
        donut_series = []
        donut_labels = []
        
        if total_sum > 0:
            for nap_label, val in nap_sums.items():
                pct = (val / total_sum) * 100
                donut_labels.append(nap_label)
                donut_series.append(round(pct, 1))

        naps_distribution = {
            "id": "naps_distribution",
            "title": "Distribución del sueño diurno",
            "type": "donut",
            "data": {
                "x_labels": donut_labels,
                "series": [{"name": "Porcentaje", "data": donut_series}]
            }
        }

        avg_per_nap = df.groupby('nap_label')['duration_hours'].mean()
        stacked_series = []
        for nap_label, val in avg_per_nap.items():
            stacked_series.append({
                "name": nap_label,
                "data": [round(val, 2)]
            })

        average_stacked = {
            "id": "average_stacked",
            "title": "Promedio de duración por siesta",
            "type": "stacked_bar",
            "data": {
                "x_labels": ["Media Diaria"],
                "series": stacked_series
            }
        }

        return {
            "summary_cards": summary_cards,
            "charts": [total_naps_trend, naps_evolution, naps_distribution, average_stacked]
        }
    
    def generate_night_sleep_stats(self, baby_id: str, start_date: str, end_date: str):
        # 1. Hacemos una llamada por cada categoría real
        bed_time_events = self.repository.get_events_by_category(baby_id, "bed_time", start_date, end_date)
        woke_up_events = self.repository.get_events_by_category(baby_id, "woke_up", start_date, end_date)
        night_waking_events = self.repository.get_events_by_category(baby_id, "night_waking", start_date, end_date)
        
        # 2. Unimos todas las listas en una sola
        raw_events = bed_time_events + woke_up_events + night_waking_events
        
        df = pd.DataFrame(raw_events)
        
        if df.empty:
            return {"summary_cards": [], "charts": []}

        df['start_time'] = pd.to_datetime(df['start_time'], format='ISO8601', utc=True)
        df['end_time'] = pd.to_datetime(df['end_time'], format='ISO8601', utc=True)
        
        # 3. Ordenamos cronológicamente todos los eventos mezclados
        df = df.sort_values('start_time').reset_index(drop=True)

        nights_data = []
        
        # 4. Iteramos sobre los inicios de noche
        for i, row in df[df['category'] == 'bed_time'].iterrows():
            bed_time = row['start_time']
            
            # Buscamos el primer woke_up que ocurra DESPUÉS de este bed_time
            future_wakes = df[(df['category'] == 'woke_up') & (df['start_time'] > bed_time)]
            if future_wakes.empty:
                continue # Si no hay woke_up, la noche aún no ha terminado
                
            woke_up = future_wakes.iloc[0]['start_time']
            
            # Buscamos los despertares que ocurrieron en medio de esa noche exacta
            wakings = df[(df['category'] == 'night_waking') & 
                         (df['start_time'] >= bed_time) & 
                         (df['start_time'] <= woke_up)]
            
            # Horas brutas en la cama
            total_night_hrs = (woke_up - bed_time).total_seconds() / 3600.0
            total_awake_hrs = 0
            
            # Restamos el tiempo despierto
            if not wakings.empty:
                total_awake_hrs = (wakings['end_time'] - wakings['start_time']).dt.total_seconds().sum() / 3600.0
                
            total_sleep_hrs = total_night_hrs - total_awake_hrs
            wake_count = len(wakings)
            
            logical_date = bed_time.strftime('%Y-%m-%d')
            
            nights_data.append({
                'logical_date': logical_date,
                'sleep_hrs': total_sleep_hrs,
                'wake_hrs': total_awake_hrs,
                'wake_count': wake_count
            })

        # 5. Preparamos el eje X
        date_range = pd.date_range(start=start_date, end=end_date).strftime('%Y-%m-%d')
        
        label_mapping = {}
        for d in date_range:
            dt_obj = pd.to_datetime(d)
            meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
            label_mapping[d] = f"{dt_obj.day} {meses[dt_obj.month - 1]}"
            
        x_labels = list(label_mapping.values())

        if not nights_data:
            return {
                "summary_cards": [
                    {"label": "Media Sueño Nocturno", "value": "0h 0m", "trend": None},
                    {"label": "Media Despertares", "value": "0", "trend": None}
                ],
                "charts": []
            }

        # 6. Agrupamos los datos
        nights_df = pd.DataFrame(nights_data)
        
        sleep_totals = nights_df.groupby('logical_date')['sleep_hrs'].sum().reindex(date_range, fill_value=0).tolist()
        wake_totals = nights_df.groupby('logical_date')['wake_hrs'].sum().reindex(date_range, fill_value=0).tolist()
        wake_counts = nights_df.groupby('logical_date')['wake_count'].sum().reindex(date_range, fill_value=0).tolist()

        # 7. KPIs
        active_nights = len(nights_df)
        avg_sleep = nights_df['sleep_hrs'].mean() if active_nights > 0 else 0
        h_s = int(avg_sleep)
        m_s = int((avg_sleep - h_s) * 60)
        avg_sleep_str = f"{h_s}h {m_s}m"

        avg_wakes = nights_df['wake_count'].mean() if active_nights > 0 else 0

        summary_cards = [
            {"label": "Media Sueño Nocturno", "value": avg_sleep_str, "trend": None},
            {"label": "Media Despertares", "value": str(round(avg_wakes, 1)), "trend": None}
        ]

        # 8. Gráficas
        total_sleep_chart = {
            "id": "night_sleep_total",
            "title": "Tiempo total dormido",
            "type": "line",
            "data": {
                "x_labels": x_labels,
                "series": [{"name": "Horas Dormidas", "data": [round(x, 2) for x in sleep_totals]}]
            }
        }

        total_wake_chart = {
            "id": "night_wake_total",
            "title": "Tiempo total despierto",
            "type": "line",
            "data": {
                "x_labels": x_labels,
                "series": [{"name": "Horas Despierto", "data": [round(x, 2) for x in wake_totals]}]
            }
        }

        wake_count_chart = {
            "id": "night_wake_count",
            "title": "Despertares por noche",
            "type": "stacked_bar",
            "data": {
                "x_labels": x_labels,
                "series": [{"name": "Despertares", "data": [int(x) for x in wake_counts]}]
            }
        }

        return {
            "summary_cards": summary_cards,
            "charts": [total_sleep_chart, total_wake_chart, wake_count_chart]
        }