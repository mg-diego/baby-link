from typing import Dict, Optional
from fastapi import HTTPException
from repositories.event_repository import EventRepository
from models.event_models import EventBase, EventCategory, EventUpdate

class EventService:
    def __init__(self, repository: EventRepository):
        self.repository = repository
        
        # Mapa de validación de metadatos (¡Actualizado con los que faltaban!)
        self._metadata_validators = {
            EventCategory.FEED: self._validate_feed_metadata,
            EventCategory.DIAPER: self._validate_diaper_metadata,
            EventCategory.MEDICINE: self._validate_medicine_metadata,
            EventCategory.TEMPERATURE: self._validate_temperature_metadata,
            EventCategory.GROWTH: self._validate_growth_metadata,
            EventCategory.PUMPING: self._validate_pumping_metadata,
            EventCategory.MILESTONE: self._validate_milestone_metadata,
        }

    def register_event(self, event: EventBase) -> dict:
        # 1. Validar estructura temporal según categoría
        self._validate_event_timing(event)

        # 2. Validar metadatos específicos
        metadata_validator = self._metadata_validators.get(event.category)
        if metadata_validator:
            metadata_validator(event.metadata)
            
        return self.repository.save(event.model_dump(mode='json'))
    
    def update_event(self, event_id: str, update_data: EventUpdate) -> dict:
        """
        Actualiza un evento existente. Ideal para cerrar cronómetros (añadir end_time)
        o actualizar metadatos al finalizar una acción.
        """
        # exclude_unset=True extrae solo los campos que el cliente ha enviado explícitamente en el JSON
        update_dict = update_data.model_dump(exclude_unset=True, mode='json')
        
        if not update_dict:
            raise HTTPException(
                status_code=400, 
                detail="El payload de actualización está vacío."
            )
            
        try:
            return self.repository.update(event_id, update_dict)
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))
        
    def get_valid_event_dates(self, baby_id: str) -> list[str]:
        if data := self.repository.get_all_start_times(baby_id):
            unique_dates = {item["start_time"][:10] for item in data if item.get("start_time")}
            return sorted(list(unique_dates))

        return []
    
    def get_last_events_by_category(self, baby_id: str) -> Dict[str, Optional[str]]:
        events_data = self.repository.get_recent_events(baby_id)
        
        last_events = {}
        for event in events_data:
            category = event['category']
            start_time = event['start_time']
            metadata = event.get('metadata') or {}
            
            if category == 'feed':
                feed_type = metadata.get('type')
                if feed_type in ['solids', 'bottle', 'nursing']:
                    if feed_type not in last_events:
                        last_events[feed_type] = start_time
                elif 'feed' not in last_events:
                    last_events['feed'] = start_time
            elif category == 'diaper':
                condition = metadata.get('condition')
                if condition in ['wet', 'dirty']:
                    key = f"diaper_{condition}"
                    if key not in last_events:
                        last_events[key] = start_time
                if 'diaper' not in last_events:
                    last_events['diaper'] = start_time
            else:
                if category not in last_events:
                    last_events[category] = start_time
                    
        return last_events

    # --- Validadores de Estructura ---

    def _validate_event_timing(self, event: EventBase):
        atomic_events = {
            EventCategory.WOKE_UP, EventCategory.BED_TIME, EventCategory.BATH, 
            EventCategory.DIAPER, EventCategory.MEDICINE, EventCategory.TEMPERATURE,
            EventCategory.GROWTH, EventCategory.MILESTONE
        }
        
        if event.category in atomic_events and event.end_time is not None:
            raise HTTPException(
                status_code=400, 
                detail=f"El evento '{event.category}' es atómico y no admite 'end_time'."
            )

        if event.category == EventCategory.FEED:
            feed_type = event.metadata.get('type')
            if feed_type != 'nursing' and event.end_time is not None:
                raise HTTPException(
                    status_code=400, 
                    detail="Solo las tomas de tipo 'nursing' admiten 'end_time'."
                )

    # --- Validadores de Metadatos (Payloads) ---

    def _validate_growth_metadata(self, metadata: dict):
        if not any(k in metadata for k in ('weight_kg', 'height_cm', 'head_cm')):
            raise HTTPException(
                status_code=400, 
                detail="Growth requiere al menos un dato: 'weight_kg', 'height_cm' o 'head_cm'"
            )

    def _validate_pumping_metadata(self, metadata: dict):
        if metadata and 'total_ml' not in metadata and 'notes' not in metadata:
            raise HTTPException(
                status_code=400, 
                detail="Si se incluyen metadatos en Pumping, debe contener 'total_ml' o 'notes'"
            )

    def _validate_milestone_metadata(self, metadata: dict):
        if 'title' not in metadata:
            raise HTTPException(
                status_code=400, 
                detail="Milestone requiere un 'title' (ej: 'Primer diente')"
            )

    def _validate_feed_metadata(self, metadata: dict):
        valid_types = ['bottle', 'nursing', 'solids']
        if 'type' not in metadata or metadata['type'] not in valid_types:
            raise HTTPException(status_code=400, detail=f"Feed debe tener type: {valid_types} \n {metadata}")

    def _validate_diaper_metadata(self, metadata: dict):
        valid_conditions = ['wet', 'dirty', 'mixed', 'clean']
        if 'condition' not in metadata or metadata['condition'] not in valid_conditions:
            raise HTTPException(status_code=400, detail=f"Diaper debe tener condition: {valid_conditions}")

    def _validate_medicine_metadata(self, metadata: dict):
        # Aceptamos que venga solo con 'notes' (por el formulario temporal de Flutter)
        # O que venga con los datos completos estrictos.
        has_strict_fields = all(k in metadata for k in ('name', 'dose_amount', 'dose_unit'))
        has_notes = 'notes' in metadata
        
        if not (has_strict_fields or has_notes):
            raise HTTPException(status_code=400, detail="Medicine requiere: name, dose_amount y dose_unit (o al menos 'notes')")

    def _validate_temperature_metadata(self, metadata: dict):
        if 'celsius' not in metadata:
            raise HTTPException(status_code=400, detail="Temperature requiere el campo 'celsius'")