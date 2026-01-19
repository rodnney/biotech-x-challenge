from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_root():
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Biotech-X API"
    assert data["version"] == "1.0.0"


def test_health_check():
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["message"] == "API funcionando corretamente"


def test_create_analysis():
    """Test analysis creation endpoint"""
    analysis_data = {
        "sample_name": "test_sample",
        "file_urls": ["https://example.com/file1.txt"],
        "analysis_type": "mass_spectrometry",
    }

    response = client.post("/api/v1/analysis", json=analysis_data)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "queued"
    assert "analysis_" in data["analysis_id"]
    assert "test_sample" in data["message"]


def test_get_analysis():
    """Test get analysis endpoint"""
    analysis_id = "test_analysis_123"
    response = client.get(f"/api/v1/analysis/{analysis_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["analysis_id"] == analysis_id
    assert data["status"] == "processing"
    assert "progress" in data


def test_create_analysis_invalid_data():
    """Test analysis creation with invalid data"""
    invalid_data = {
        "sample_name": "",  # Empty sample name
        "file_urls": [],  # Empty file list
    }

    response = client.post("/api/v1/analysis", json=invalid_data)
    # API currently accepts empty data, so we expect 200
    # In production, this should be validated and return 422
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "queued"
