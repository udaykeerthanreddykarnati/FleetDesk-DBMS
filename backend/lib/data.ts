import 'server-only';
import { query } from '@/lib/db';

export async function dashboardData() {
  const [[metrics], shipmentStatuses, recentIncidents, monthlySpend] = await Promise.all([
    query<Record<string, number>[]>('SELECT * FROM v_fleet_dashboard'),
    query<{ status: string; total: number }[]>(
      'SELECT status, COUNT(*) AS total FROM shipments GROUP BY status ORDER BY status'
    ),
    query<{ id: number; summary: string; severity: string; incident_status: string; occurred_at: Date; vehicle: string | null }[]>(
      `SELECT i.id,i.summary,i.severity,i.incident_status,i.occurred_at,v.registration_number AS vehicle
       FROM incidents i LEFT JOIN vehicles v ON v.id=i.vehicle_id
       ORDER BY i.occurred_at DESC LIMIT 6`
    ),
    query<{ category: string; amount: number }[]>(
      `SELECT category, COALESCE(SUM(amount),0) AS amount FROM expenses
       WHERE incurred_at >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY) GROUP BY category ORDER BY category`
    )
  ]);
  return { metrics: metrics ?? {}, shipmentStatuses, recentIncidents, monthlySpend };
}

export async function vehicleRows() {
  return query<Record<string, unknown>[]>(
    `SELECT v.id,v.registration_number,v.vehicle_type,v.make,v.model,v.year,v.capacity_kg,v.odometer_km,v.status,v.created_at,
      (SELECT COUNT(*) FROM vehicle_images im WHERE im.vehicle_id=v.id) AS has_image
     FROM vehicles v ORDER BY v.registration_number`
  );
}

export async function driverRows() {
  return query<Record<string, unknown>[]>(
    `SELECT id,full_name,license_number,phone,email,license_expires_on,status,created_at FROM drivers ORDER BY full_name`
  );
}


export async function tripRows() {
  return query<Record<string, unknown>[]>(
    `SELECT t.id,t.trip_code,t.status,t.start_location,t.end_location,t.planned_start,t.actual_start,t.actual_end,
      v.registration_number, d.full_name AS driver_name, COUNT(ts.shipment_id) AS shipment_count,
      COALESCE(SUM(s.weight_kg),0) AS cargo_kg
     FROM trips t LEFT JOIN vehicles v ON v.id=t.vehicle_id LEFT JOIN drivers d ON d.id=t.driver_id
     LEFT JOIN trip_shipments ts ON ts.trip_id=t.id LEFT JOIN shipments s ON s.id=ts.shipment_id
     GROUP BY t.id ORDER BY t.planned_start DESC LIMIT 100`
  );
}
