import firebase_admin
from firebase_admin import credentials, firestore
import csv

# Initialize Firebase Admin SDK (Replace with your own serviceAccountKey.json)
cred = credentials.Certificate("/Users/jaeman/Downloads/wakeup-74d89-firebase-adminsdk-ppan8-f0eb18b7c7.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Function to upload dangerous locations from CSV
def upload_dangerous_locations(csv_file):
    with open(csv_file, newline='') as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            latitude = float(row[0])
            longitude = float(row[1])
            
            # Upload to Firestore
            db.collection('DangerousLocations').add({
                'WGS84': firestore.GeoPoint(latitude, longitude)
            })
            print(f'Uploaded location: ({latitude}, {longitude})')

# Replace with the path to your CSV files
upload_dangerous_locations('/Users/jaeman/Downloads/전국교통사고다발지역표준데이터_RAW.csv')
upload_dangerous_locations('/Users/jaeman/Downloads/output_RAW.csv')
