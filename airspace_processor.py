import pandas as pd
import json
import numpy as np
import pytz
from haversine import haversine, Unit
import warnings
import awswrangler as wr


query = '''
SELECT 
    airspace_route.order_id, 
    airspace_orders.company_id, 
    airspace_start_addresses.city as origin_city, 
    airspace_end_addresses.city as destination_city,
    airspace_orders.pick_up_time as pick_up_time_local,
    airspace_orders.quoted_delivery_time as delivery_time,
    airspace_start_addresses.time_zone as start_time_zone,
    airspace_orders.created_at as create_time,
    airspace_route.type as route_type,
    airspace_end_addresses.time_zone as end_time_zone,
    airspace_searches.miles as miles,
    airspace_start_addresses.lat as start_lat,
    airspace_start_addresses.lng as start_lng,
    airspace_end_addresses.lat as end_lat,
    airspace_end_addresses.lng as end_lng
FROM airspace_route
FULL OUTER JOIN airspace_start_addresses
    ON airspace_route.start_address_id=airspace_start_addresses.id
FULL OUTER JOIN airspace_end_addresses
    ON airspace_route.end_address_id=airspace_end_addresses.id
FULL OUTER JOIN airspace_orders
    ON airspace_route.order_id=airspace_orders.id
FULL OUTER Join airspace_searches
    ON airspace_route.driving_search_id=airspace_searches.id
'''

def to_miles( number, measure ):
  if measure == 'km':
    return number * 0.621371
  if measure == 'm':
    return number * 0.000621371192
  if measure == 'ft':
    return number * 5280
  else:
    return measure
    
def get_order_type( route_type ):
  if ( len(route_type) == 1 and route_type[0] == '"DrivingSegment"' ):
    return 'drive'
  if ( route_type.count('"FlyingSegment"') == route_type.count('"DrivingSegment"') ):
    return 'hfpu'
  else:
    return 'nfo'
    
def clean_timezone( timezone ):
  if ( 
    timezone == '"Pacific Time (US & Canada)"' or timezone == '"CA'
  ):
    return 'America/Los_Angeles'
  if ( timezone == '"America/Indiana/Indianapolis"' ):
    return 'America/Chicago'
  else:
    return timezone.replace('\"', '').replace("'", "")

def airspace_processor(event, context):
  out = {}
  out['order_id'] = []
  out['company_id'] = []
  out['origin_city'] = []
  out['destination_city'] = []
  out['pick_up_time_local'] = []
  out['delivery_time'] = []
  out['minutes_to_pickup'] = []
  out['order_type'] = []
  out['total_drive_distance'] = []
  out['total_distance'] = []
  print( 'querying' )
  df = wr.athena.read_sql_query( sql=query, database="airspace" )
  # Set the datetimes as datetimes
  df['pick_up_time_local'] = pd.to_datetime( df['pick_up_time_local'].str.replace('"', ''), utc=True )
  df['delivery_time'] = pd.to_datetime( df['delivery_time'].str.replace('"', ''), utc=True )
  df['create_time'] = pd.to_datetime( df['create_time'].str.replace('"', ''), utc=True )


  # Iterate over the differnet Order ID's
  for order_id, temp in df.groupby('order_id'):
    out['order_id'].append( order_id )
    out['company_id'].append( temp['company_id'].iloc[0] )
    # Get the miles driven
    out['total_drive_distance'].append( temp['miles'].sum() )
    # Get the order type
    out['order_type'].append( get_order_type( temp['route_type'].tolist() ) )
    # Get the origin and destination city
    out['origin_city'].append( temp['origin_city'].iloc[0] )
    out['destination_city'].append( temp['destination_city'].iloc[-1] )
    # Get the distance between the cities
    out['total_distance'].append(
      haversine(
        (temp['start_lat'].iloc[0], temp['start_lng'].iloc[0]),
        (temp['end_lat'].iloc[0], temp['end_lng'].iloc[0]),
        unit=Unit.MILES
      )
    )
    # Set the times
    if ( 
      pd.isnull( temp['pick_up_time_local'].iloc[0] ) or  
      pd.isnull( temp['start_time_zone'].iloc[0] )
    ):
      out['pick_up_time_local'].append( np.datetime64('NaT') )
    else:
      out['pick_up_time_local'].append(
        temp['pick_up_time_local'].iloc[0].astimezone( 
          clean_timezone( temp['start_time_zone'].iloc[0] )
        )
      )
    if ( 
      pd.isnull( temp['delivery_time'].iloc[0] ) or
      pd.isnull( temp['end_time_zone'].iloc[0] )
    ):
      out['delivery_time'].append( np.datetime64('NaT') )
    else:
      out['delivery_time'].append( 
        temp['delivery_time'].iloc[0].astimezone( 
          clean_timezone( temp['end_time_zone'].iloc[0] )
        )
      )
    # Get the difference between order creation and order pickup
    out['minutes_to_pickup'].append(
      abs(
        (temp['pick_up_time_local'].iloc[0] - temp['create_time'].iloc[0]).total_seconds() / 60
      )
    )
  print(  pd.DataFrame(out).sort_values('total_distance') )
  return {
    'statusCode': 200,
    'body': json.dumps(f'tyler')
  }
