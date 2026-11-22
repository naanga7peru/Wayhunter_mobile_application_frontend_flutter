enum ModuleId { traveler, hunter, game }

enum PlaceSource { hunterApproved, externalProvider }

bool isNavigationId(String value) =>
    RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.:-]{0,254}$').hasMatch(value);

class UserRef {
  const UserRef(this.id);
  final String id;
}

class PlaceRef {
  const PlaceRef(this.id, {required this.source});
  final String id;
  final PlaceSource source;
}

class TripPlanRef {
  const TripPlanRef(this.id);
  final String id;
}

class TripSessionRef {
  const TripSessionRef(this.id);
  final String id;
}
