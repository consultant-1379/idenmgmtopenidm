/*
 * COPYRIGHT Ericsson 2014
 *
 * The copyright to the computer program(s) herein is the property of
 * Ericsson Inc. The programs may be used and/or copied only with written
 * permission from Ericsson Inc. or in accordance with the terms and
 * conditions stipulated in the agreement/contract under which the
 * program(s) have been supplied.
 */
package com.ericsson.oss.security.idenmgmt.session;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.util.Properties;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.security.auth.callback.Callback;
import javax.security.auth.callback.NameCallback;
import javax.security.auth.callback.PasswordCallback;

import com.iplanet.am.util.SystemProperties;
import com.iplanet.sso.SSOToken;
import com.iplanet.sso.SSOTokenManager;
import com.sun.identity.authentication.AuthContext;
import com.sun.identity.shared.ldap.LDAPDN;


public class SessionInvalidation {
	
	private static SessionInvalidation instance;
	
	private static Logger logger = Logger.getLogger(SessionInvalidation.class.getName());
	
	private String adminPassword;
	private String openAMUrl;

	/**
	 *  Method returns instance of SessionInvalidation singleton.
	 *
	 *  @return SessionInvalidation instance
	 */	
	public static synchronized SessionInvalidation getInstance() {
		if(instance == null) {
			instance = new SessionInvalidation();
			instance.initialize();
		}
		return instance;
	}
	
	private void initialize() {
		Properties properties = new Properties();
		try {
			properties.load(SessionInvalidation.class.getResourceAsStream("/config.properties"));
		} catch(Exception ex) {
			logger.log(Level.SEVERE, "Failed to load configuration properties", ex);
			return;
		}
				
		replaceHostName(properties);
		
		openAMUrl = createOpenAMUrl(properties);
		properties.put("com.iplanet.am.naming.url", openAMUrl + "/namingservice");	

		adminPassword = "h31md477R";
		properties.put("com.iplanet.am.service.password", adminPassword);
		
		SystemProperties.initializeProperties(properties);
	}

	private void replaceHostName(Properties properties) {
		String host = properties.getProperty(("com.iplanet.am.server.host"));
		host = host.replaceAll("apache\\.vts\\.com", getHost());
		properties.put("com.iplanet.am.server.host", host);
	}

	private String getHost() {
		try {
			//TODO temporary solution, needs to be updated in the future
			String[] cmd = {"/bin/sh", "-c", "/usr/bin/getent hosts httpd | /bin/awk '{print $4}'"};
			Process process = Runtime.getRuntime().exec(cmd);
			process.waitFor();
			
			BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
			return reader.readLine();
		} catch(Exception ex) {
			logger.log(Level.SEVERE, "Failed to read fully qualified domain name", ex);
		}
		return "";
	}

	private String createOpenAMUrl(Properties properties) {
		StringBuilder sb = new StringBuilder();
		sb.append(properties.getProperty("com.iplanet.am.server.protocol"));
		sb.append("://");
		sb.append(properties.getProperty("com.iplanet.am.server.host"));
		sb.append(":");
		sb.append(properties.getProperty("com.iplanet.am.server.port"));
		sb.append(properties.getProperty("com.iplanet.am.services.deploymentDescriptor"));
		return sb.toString();
	}
	
	private void login(String userName, String password, AuthContext context) {
		try {
			context.login(AuthContext.IndexType.MODULE_INSTANCE, "DataStore");
		
			Callback[] callbacks;
			while(context.hasMoreRequirements()) {
				callbacks = context.getRequirements();
				
				for(int i=0; i<callbacks.length; i++) {
					if(callbacks[i] instanceof NameCallback) {
						NameCallback nc = (NameCallback) callbacks[i];
						nc.setName(userName);
					} else if(callbacks[i] instanceof PasswordCallback) {
						PasswordCallback pc = (PasswordCallback) callbacks[i];
						pc.setPassword(password.toCharArray());
					}
				}
				
				context.submitRequirements(callbacks);
			}
		} catch(Exception ale) {
			logger.log(Level.SEVERE, "Failed to login as amAdmin", ale);
		}
	}
	
	private boolean isLoginSuccess(AuthContext context) {
		return context.getStatus() == AuthContext.Status.SUCCESS;
	}
	
	private boolean isPrincipal(SSOToken token, String userName) {
		try {
			String[] principalDN = LDAPDN.explodeDN(token.getPrincipal().getName(), true);
			return principalDN.length != 0 && userName.equals(principalDN[0]);
		} catch(Exception ex) {
			logger.log(Level.SEVERE, "Failed to get session info", ex);
		}
		return false;
	}
	
	/**
	 * Method invalidates sessions of a given user.
	 *  
	 * @param userName
	 *	- String representing the user name
	 */
	public void invalidateSessions(String userName) {
		try {
			AuthContext adminContext = new AuthContext("/");
			login("amAdmin", adminPassword, adminContext);

			if(isLoginSuccess(adminContext)) {
				SSOToken adminToken = adminContext.getSSOToken();
				SSOTokenManager tokenManager = SSOTokenManager.getInstance();
				Set<SSOToken> sessions = tokenManager.getValidSessions(adminToken, openAMUrl);
				for(SSOToken token : sessions) {
					if(isPrincipal(token, userName)) {
						tokenManager.destroyToken(adminToken, token);
					}
				}
				adminContext.logout();
			}
		} catch(Exception ex) {
			logger.log(Level.SEVERE, "Failed to invalidate user sessions", ex);
		}
	}
}

