import pytest
from fastapi.testclient import TestClient

from backend.main import app

client = TestClient(app)


def test_auth_me_requires_authentication():
    response = client.get('/auth/me')
    assert response.status_code == 401


def test_auth_me_returns_authenticated_doctor():
    login = client.post(
        '/auth/login',
        json={
            'identifier': 'DOC-001',
            'password': 'Drishti@123',
            'role': 'doctor',
        },
    )
    assert login.status_code == 200, login.text
    token = login.json()['token']

    response = client.get(
        '/auth/me',
        headers={'Authorization': f'Bearer {token}'},
    )
    assert response.status_code == 200, response.text
    doctor = response.json()['doctor']
    assert doctor['doctor_id'] == 'DOC-001'
    assert doctor['name'] == 'Dr. Ananya Sharma'
    assert 'password_hash' not in doctor


def test_auth_me_update_rejects_doctor_id_mutation():
    login = client.post(
        '/auth/login',
        json={
            'identifier': 'DOC-002',
            'password': 'Drishti@123',
            'role': 'doctor',
        },
    )
    token = login.json()['token']

    payload = {
        'doctor_id': 'DOC-999',
        'name': 'Dr. Rohan Mehta Updated',
        'email': 'rohan.mehta.updated@drishti.local',
        'phone': '9876543210',
        'date_of_birth': '1990-08-12',
        'gender': 'Male',
        'medical_registration_number': 'MR-2024-010',
        'specialization': 'Retina',
        'qualification': 'MBBS, MS',
        'years_of_experience': 7,
        'hospital_clinic': 'Drishti Eye Care',
    }

    response = client.put(
        '/auth/me',
        json=payload,
        headers={'Authorization': f'Bearer {token}'},
    )
    assert response.status_code == 200, response.text
    doctor = response.json()['doctor']
    assert doctor['doctor_id'] == 'DOC-002'
    assert doctor['name'] == 'Dr. Rohan Mehta Updated'
    assert doctor['email'] == 'rohan.mehta.updated@drishti.local'


def test_auth_me_update_rejects_medical_registration_number_mutation():
    login = client.post(
        '/auth/login',
        json={
            'identifier': 'DOC-003',
            'password': 'Drishti@123',
            'role': 'doctor',
        },
    )
    token = login.json()['token']

    original_mrn = login.json()['doctor']['medical_registration_number']

    payload = {
        'name': 'Dr. Priya Kulkarni Updated',
        'email': 'priya.kulkarni.updated@drishti.local',
        'phone': '9988776655',
        'date_of_birth': '1990-06-19',
        'gender': 'Female',
        'medical_registration_number': 'MR-9999-999',
        'specialization': 'Retinal Imaging',
        'qualification': 'MBBS, DNB (Ophthalmology)',
        'years_of_experience': 7,
        'hospital_clinic': 'Updated Eye Hospital',
    }

    response = client.put(
        '/auth/me',
        json=payload,
        headers={'Authorization': f'Bearer {token}'},
    )
    assert response.status_code == 200, response.text
    doctor = response.json()['doctor']
    assert doctor['medical_registration_number'] == original_mrn
    assert doctor['name'] == 'Dr. Priya Kulkarni Updated'
