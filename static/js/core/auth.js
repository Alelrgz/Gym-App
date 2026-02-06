/**
 * Authentication Module
 * Handles token management, auth interceptor, and logout
 */

// Bootstrap from Server if valid token present in config
export function initAuth() {
    if (window.APP_CONFIG.token && window.APP_CONFIG.token !== "None") {
        console.log("Bootstrapping auth from server...");
        localStorage.setItem('token', window.APP_CONFIG.token);
        localStorage.setItem('role', window.APP_CONFIG.role);
    }

    if (!localStorage.getItem('token') && window.location.pathname !== '/auth/login' && window.location.pathname !== '/auth/register') {
        window.location.href = '/auth/login';
    }
}

// Setup fetch interceptor for auth headers
export function setupAuthInterceptor() {
    const originalFetch = window.fetch;
    window.fetch = async function (url, options = {}) {
        const token = localStorage.getItem('token');
        if (token) {
            options.headers = options.headers || {};
            if (!options.headers['Authorization']) {
                options.headers['Authorization'] = `Bearer ${token}`;
            }
        }
        console.log("FETCH Request:", url, "Headers:", options.headers);

        try {
            const response = await originalFetch(url, options);
            if (response.status === 401 && window.location.pathname !== '/auth/login') {
                localStorage.removeItem('token');
                window.location.href = '/auth/login';
            }
            return response;
        } catch (e) {
            throw e;
        }
    };
}

// Logout function
export function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('role');
    window.location.href = '/auth/logout';
}

// Make logout globally available
window.logout = logout;
