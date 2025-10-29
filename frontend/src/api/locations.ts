import { Location, LocationCreateRequest } from '../types';

const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'http://localhost:8080';

class LocationService {
  private getAuthHeaders() {
    const token = localStorage.getItem('token');
    return {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
    };
  }

  async getAllActiveLocations(): Promise<Location[]> {
    const response = await fetch(`${API_BASE_URL}/api/locations/active`, {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('활성 장소 조회에 실패했습니다.');
    }

    return response.json();
  }

  async getAllLocations(): Promise<Location[]> {
    const response = await fetch(`${API_BASE_URL}/api/locations`, {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('장소 조회에 실패했습니다.');
    }

    return response.json();
  }

  async getLocationById(id: number): Promise<Location> {
    const response = await fetch(`${API_BASE_URL}/api/locations/${id}`, {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('장소 조회에 실패했습니다.');
    }

    return response.json();
  }

  async createLocation(request: LocationCreateRequest): Promise<Location> {
    const response = await fetch(`${API_BASE_URL}/api/locations`, {
      method: 'POST',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || '장소 생성에 실패했습니다.');
    }

    return response.json();
  }

  async updateLocation(id: number, request: LocationCreateRequest): Promise<Location> {
    const response = await fetch(`${API_BASE_URL}/api/locations/${id}`, {
      method: 'PUT',
      headers: this.getAuthHeaders(),
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || '장소 수정에 실패했습니다.');
    }

    return response.json();
  }

  async deactivateLocation(id: number): Promise<void> {
    const response = await fetch(`${API_BASE_URL}/api/locations/${id}/deactivate`, {
      method: 'PUT',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || '장소 비활성화에 실패했습니다.');
    }
  }

  async activateLocation(id: number): Promise<void> {
    const response = await fetch(`${API_BASE_URL}/api/locations/${id}/activate`, {
      method: 'PUT',
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || '장소 활성화에 실패했습니다.');
    }
  }

  async searchLocations(keyword: string): Promise<Location[]> {
    const response = await fetch(`${API_BASE_URL}/api/locations/search?keyword=${encodeURIComponent(keyword)}`, {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('장소 검색에 실패했습니다.');
    }

    return response.json();
  }

  async getLocationsInUse(): Promise<Location[]> {
    const response = await fetch(`${API_BASE_URL}/api/locations/in-use`, {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      throw new Error('사용 중인 장소 조회에 실패했습니다.');
    }

    return response.json();
  }
}

export const locationService = new LocationService();