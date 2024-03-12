class CalSelector {
  bool isSelected = false;
  late ({
    String name,
    String type,
    List<int> size,
    List phys,
    List sst_ref,
    List sst_x,
    List sst_y
  }) calibration;

  CalSelector(dynamic object) {
    calibration = object as ({
      String name,
      List phys,
      List<int> size,
      List sst_ref,
      List sst_x,
      List sst_y,
      String type
    });
  }
}
