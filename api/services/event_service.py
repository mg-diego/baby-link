from fastapi import HTTPException
from repositories.event_repository import EventRepository
from models.event_models import EventBase, EventCategory, EventUpdate

class EventService:
    def __init__(self, repository: EventRepository):
        self.repository = repository
        
        # Mapa de validación de metadatos
        self._metadata_validators = {
            EventCategory.FEED: self._validate_feed_metadata,
            EventCategory.DIAPER: self._validate_diaper_metadata,
            EventCategory.MEDICINE: self._validate_medicine_metadata,
            EventCategory.TEMPERATURE: self._validate_temperature_metadata,
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
            
        # Si el cliente envía metadatos nuevos, podríamos validarlos aquí si es necesario
        # (Para una versión V1, asumimos que el payload extra de cerrado es correcto)
        
        try:
            return self.repository.update(event_id, update_dict)
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))

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
            if feed_type != 'breast' and event.end_time is not None:
                raise HTTPException(
                    status_code=400, 
                    detail="Solo las tomas de tipo 'breast' admiten 'end_time'."
                )

    # --- Validadores de Metadatos (Payloads) ---

    def _validate_growth_metadata(self, metadata: dict):
        # Exigimos al menos un dato métrico para que el registro tenga sentido
        if not any(k in metadata for k in ('weight_kg', 'height_cm', 'head_cm')):
            raise HTTPException(
                status_code=400, 
                detail="Growth requiere al menos un dato: 'weight_kg', 'height_cm' o 'head_cm'"
            )

    def _validate_pumping_metadata(self, metadata: dict):
        # Como es Start-Stop, al inicio puede estar vacío. 
        # Si envían datos (al hacer el PATCH de cierre), verificamos que envíen el total.
        if metadata and 'total_ml' not in metadata:
            raise HTTPException(
                status_code=400, 
                detail="Si se incluyen metadatos en Pumping, debe contener 'total_ml'"
            )

    def _validate_milestone_metadata(self, metadata: dict):
        if 'title' not in metadata:
            raise HTTPException(
                status_code=400, 
                detail="Milestone requiere un 'title' (ej: 'Primer diente')"
            )

    def _validate_feed_metadata(self, metadata: dict):
        valid_types = ['bottle', 'breast', 'solids']
        if 'type' not in metadata or metadata['type'] not in valid_types:
            raise HTTPException(status_code=400, detail=f"Feed debe tener type: {valid_types}")

    def _validate_diaper_metadata(self, metadata: dict):
        valid_conditions = ['wet', 'dirty', 'mixed', 'clean']
        if 'condition' not in metadata or metadata['condition'] not in valid_conditions:
            raise HTTPException(status_code=400, detail=f"Diaper debe tener condition: {valid_conditions}")

    def _validate_medicine_metadata(self, metadata: dict):
        if not all(k in metadata for k in ('name', 'dose_amount', 'dose_unit')):
            raise HTTPException(status_code=400, detail="Medicine requiere: name, dose_amount y dose_unit")

    def _validate_temperature_metadata(self, metadata: dict):
        if 'celsius' not in metadata:
            raise HTTPException(status_code=400, detail="Temperature requiere el campo 'celsius'")