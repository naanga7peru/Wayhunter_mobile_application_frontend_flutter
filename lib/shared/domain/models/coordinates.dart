bool validCoordinates(num? latitude, num? longitude) =>
    (latitude == null && longitude == null) ||
    (latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180);
