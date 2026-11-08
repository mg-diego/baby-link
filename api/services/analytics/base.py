from repositories.analytics_repository import AnalyticsRepository


class StatsBase:
    def __init__(self, repository: AnalyticsRepository):
        self.repository = repository
        self.tz = str(repository.tz)
