class DashboardStats {
  final int totalCaptains;
  final int approvedCaptains;
  final int pendingCaptains;
  final int onlineCaptains;
  final int totalTrips;
  final int activeTrips;
  final int completedTrips;
  final int cancelledTrips;
  final int tripsToday;
  final int newCaptainsToday;
  final double platformRevenue;
  final double captainEarnings;
  final double commissionCollected;
  final int pendingRechargeRequests;
  final int pendingWithdrawalRequests;

  const DashboardStats({
    this.totalCaptains = 0,
    this.approvedCaptains = 0,
    this.pendingCaptains = 0,
    this.onlineCaptains = 0,
    this.totalTrips = 0,
    this.activeTrips = 0,
    this.completedTrips = 0,
    this.cancelledTrips = 0,
    this.tripsToday = 0,
    this.newCaptainsToday = 0,
    this.platformRevenue = 0,
    this.captainEarnings = 0,
    this.commissionCollected = 0,
    this.pendingRechargeRequests = 0,
    this.pendingWithdrawalRequests = 0,
  });
}
