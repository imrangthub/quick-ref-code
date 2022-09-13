
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Date;

import org.apache.commons.lang3.StringUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.web.multipart.MultipartFile;

import oracle.jdbc.OracleCallableStatement;
import oracle.jdbc.OracleTypes;

/**
 * @author MD IMRAN HOSSAIN
 *
 */
public class DefaultFan {

	static String dateFormat;

	public final static String stringType = "String";
	public final static String longType = "Long";
	public final static String floatType = "Float";
	public final static String doubleType = "Double";
	public final static String intType = "int";
	public final static String integerType = "Integer";
	public final static String stringTypeArray = "StringArray";
	public final static String longTypeArray = "LongArray";
	public final static String floatTypeArray = "FloatArray";
	public final static String doubleTypeArray = "DoubleArray";
	public final static String integerTypeArray = "IntegerArray";
	public final static String intTypeArray = "intArray";


	/**
	 * @param jsonStr
	 * @return
	 */
	public static JSONObject getJSONObject() {
		JSONObject json = new JSONObject();
		return json;
	}
	
	
	/**
	 * @param jsonStr
	 * @return
	 */
	public static JSONObject getJSONObject(String jsonStr) {
		JSONObject json = new JSONObject(jsonStr);
		return json;
	}

	/**
	 * 
	 * @param json
	 * @param key
	 * @return String
	 */
	@SuppressWarnings("static-access")
	public static String getString(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.NULL != json.get(key) && !StringUtils.isBlank(json.get(key).toString()) && !json.get(key).equals("{}")) {
				return json.get(key).toString();
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * @param json
	 * @param key
	 * @return
	 */
	public static Object getObjcect(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && json.get(key) != null) {
				return json.get(key);
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * @param json
	 * @param key
	 * @return
	 */
	public static String getArrayString(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && json.get(key) != null) {
				return json.getJSONArray(key).toString();
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * @param json
	 * @param key
	 * @return
	 */
	public static Object getArrayObj(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && json.get(key) != null) {
				return json.getJSONArray(key);
			} else {
				return null;
			}
		}
		return null;
	}
	
	public static String jsonObjectCovertToString(JSONObject json) {
		
		return json.toString();
	}
	
	public static JSONObject addJavaObjectToJsonObject(JSONObject json , String key, Object obj) {
		return json.put(key, obj);
		
	}
	
	public static String addJavaObjectToJsonObjectString(JSONObject json , String key, Object obj) {
		return json.put(key, obj).toString();
		
	}
	public static String addJavaObjectToJsonObjectString(JSONObject json , String key, Object obj,String key1, Object obj1) {
		 json.put(key, obj);
		 json.put(key1, obj1);
		 return json.toString();
		
	}


	/**
	 * @param json
	 * @param key
	 * @return
	 */
	public static JSONArray getJSONArray(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && json.get(key) != null) {
				return json.getJSONArray(key);
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * 
	 * @param json
	 * @param key
	 * @retur Long
	 */
	public static Long getLong(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && !json.isNull(key)) {
				return Long.parseLong(json.get(key).toString());
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * @param json
	 * @param key
	 * @retur Boolean
	 */
	public static Boolean getBoolean(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && !json.isNull(key)) {
				return Boolean.parseBoolean(json.get(key).toString());
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * @param json
	 * @param key
	 * @return
	 */
	public static Long[] getArrayLong(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != null) {
				return jsonArryToLongtArry(getJSONArray(json, key));
			} else {
				return null;
			}
		}
		return null;
	}

	public static Long[] jsonArryToLongtArry(JSONArray arr) {
		Long[] item = new Long[arr.length()];
		for (int i = 0; i < arr.length(); ++i) {
			item[i] = arr.optLong(i);
		}
		return item;
	}

	public static Float[] jsonArryToFloatArry(JSONArray arr) {
		Float[] item = new Float[arr.length()];
		for (int i = 0; i < arr.length(); ++i) {
			item[i] = arr.optFloat(i);
		}
		return item;
	}

	/**
	 * 
	 * @param json
	 * @param key
	 * @retur Double
	 */
	public static Double getDouble(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && json.get(key) != null) {
				return Double.parseDouble(json.get(key).toString());
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * 
	 * @param json
	 * @param key
	 * @return Integer
	 */
	public static Integer getInteger(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && json.get(key) != null) {
				return Integer.parseInt(json.get(key).toString());
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * 
	 * @param json
	 * @param key
	 * @return date
	 */
	public static Date getDate(JSONObject json, String key) {
		SimpleDateFormat formatter = null;
		if (Def.dateFormat == null) {
			formatter = new SimpleDateFormat("dd/MM/yyyy HH:mm:ss");
		} else {
			formatter = new SimpleDateFormat(Def.dateFormat);
		}

		if (json.has(key)) {

			if (!json.get(key).equals("") && json.get(key) != null) {
				try {
					return formatter.parse(json.get(key).toString());
				} catch (JSONException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				} catch (ParseException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
			} else {
				return null;
			}
		}
		return null;
	}

	/**
	 * 
	 * @param json
	 * @param key
	 * @param dateFromat
	 * @return date
	 */
	public static Date getDate(JSONObject json, String key, String dateFromat) {
		Def.dateFormat = dateFromat;
		return Def.getDate(json, key);
	}

	/**
	 * @param dateStr
	 * @return
	 */
	public static Date DateParse(String dateStr) {
		Date date = null;
		SimpleDateFormat formatter = null;
		if (Def.dateFormat == null) {
			formatter = new SimpleDateFormat("dd/MM/yyyy HH:mm:ss");
		} else {
			formatter = new SimpleDateFormat(Def.dateFormat);
		}
		try {
			date = formatter.parse(dateStr);
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return date;
	}

	/**
	 * @param dateStr
	 * @param format
	 * @return
	 */
	public static Date DateParse(String dateStr, String format) {
		Def.dateFormat = format;
		Date date = null;
		SimpleDateFormat formatter = null;
		if (Def.dateFormat == null) {
			formatter = new SimpleDateFormat("dd/MM/yyyy HH:mm:ss");
		} else {
			formatter = new SimpleDateFormat(Def.dateFormat);
		}
		try {
			date = formatter.parse(dateStr);
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return date;
		}

		return date;
	}

//	/**
//	 * @param dateStr
//	 * @return
//	 */
//	public static String getTime(String dateStr) {
//		Date date = null;
//		SimpleDateFormat formatter = null;
//		formatter = new SimpleDateFormat("HH:mm:ss");
//		try {
//			date = formatter.parse(dateStr);
//		} catch (ParseException e) {
//			// TODO Auto-generated catch block
//			e.printStackTrace();
//			return date;
//		}
//
//		return date;
//	}

	/**
	 * @param date
	 * @return
	 */
	public static String getTime(Date date) {
		String timeStr = null;
		try {
			LocalTime localTime = date.toInstant().atZone(ZoneId.systemDefault()).toLocalTime();
			DateTimeFormatter dateTimeFormatter = DateTimeFormatter.ofPattern("hh:mm a");
			timeStr = localTime.format(dateTimeFormatter);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return timeStr;
		}
		return timeStr;
	}

	/**
	 * @param date
	 * @return
	 */
	public static String getDate(Date date) {
		String timeStr = null;
		try {
			LocalDate localDate = date.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
			DateTimeFormatter dateDateFormatter = DateTimeFormatter.ofPattern("dd-MMM-yyyy");
			timeStr = localDate.format(dateDateFormatter);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return timeStr;
		}
		return timeStr;
	}

	/**
	 * @param json
	 * @param key
	 * @return
	 */
	public static Float getFloat(JSONObject json, String key) {
		if (json.has(key)) {
			if (json.get(key) != "" && !json.get(key).toString().isEmpty() && json.get(key) != null) {

				return Float.parseFloat(json.get(key).toString());

			} else {
				return null;
			}
		}
		return null;
	}

	public static void connectionClose(Connection conn, OracleCallableStatement stmt) {
		if (conn != null) {
			try {
				conn.close();
			} catch (SQLException e) {
				e.printStackTrace();
			}
		}
		if (stmt != null) {
			try {
				stmt.close();
			} catch (SQLException e) {
				e.printStackTrace();
			}
		}
	}

	public static void connectionClose(Connection conn, OracleCallableStatement stmt, ResultSet rs) {
		if (conn != null) {
			try {
				conn.close();
			} catch (SQLException e) {
				e.printStackTrace();
			}
		}
		if (stmt != null) {
			try {
				stmt.close();
			} catch (SQLException e) {
				e.printStackTrace();
			}
		}
		if (rs != null) {
			try {
				rs.close();
			} catch (SQLException e) {
				e.printStackTrace();
			}
		}
	}

	public static OracleCallableStatement setLongArray(int index, Long[] strArray, OracleCallableStatement oras)
			throws SQLException {
		oras.setPlsqlIndexTable(index, strArray, strArray.length, strArray.length, OracleTypes.NUMBER, strArray.length);
		return oras;
	}

	public static OracleCallableStatement setFloatArray(int index, Float[] strArray, OracleCallableStatement oras)
			throws SQLException {
		oras.setPlsqlIndexTable(index, strArray, strArray.length, strArray.length, OracleTypes.NUMBER, strArray.length);
		return oras;
	}

	public static OracleCallableStatement setIntegerArray(int index, Integer[] strArray, OracleCallableStatement oras)
			throws SQLException {
		oras.setPlsqlIndexTable(index, strArray, strArray.length, strArray.length, OracleTypes.NUMBER, strArray.length);
		return oras;
	}

	public static OracleCallableStatement setDoubleArray(int index, Double[] strArray, OracleCallableStatement oras)
			throws SQLException {
		oras.setPlsqlIndexTable(index, strArray, strArray.length, strArray.length, OracleTypes.NUMBER, strArray.length);
		return oras;
	}

	public static OracleCallableStatement setStringArray(int index, String[] strArray, OracleCallableStatement oras)
			throws SQLException {
		oras.setPlsqlIndexTable(index, strArray, strArray.length, strArray.length, OracleTypes.VARCHAR, 0);
		return oras;
	}

	public static OracleCallableStatement setDateArray(int index, Date[] strArray, OracleCallableStatement oras)
			throws SQLException {

		java.sql.Date[] strArray1 = new java.sql.Date[strArray.length];

		for (int i = 0; i < strArray.length; i++) {
			strArray1[i] = new java.sql.Date(strArray[i].getTime());
		}

//		strArray1 [0] = new java.sql.Date(new Date().getTime());
//		strArray1 [1] = new java.sql.Date(new Date().getTime());

		System.out.println(index);
		System.out.println(strArray1);

		oras.setPlsqlIndexTable(index, strArray1, strArray1.length, strArray1.length, OracleTypes.DATE,
				strArray1.length);
		return oras;
	}

	public static Long[] jsonArryToLongArry(JSONArray arr) {
		Long[] item = new Long[arr.length()];
		for (int i = 0; i < arr.length(); ++i) {
			item[i] = arr.getLong(i);
		}
		return item;
	}

	public static JSONArray stringToJsonArry(JSONObject jsonObj, String key) {
		Object objBykey = Def.getObjcect(jsonObj, key);
		JSONArray jsonArray = new JSONArray();
		if (objBykey instanceof JSONArray) {
			jsonArray = (JSONArray) objBykey;
		} else if (objBykey instanceof String) {
			jsonArray.put(objBykey);
		}
		return jsonArray;
	}

	public static JSONObject getJSONObjectFromJSONArray(JSONArray jsonArray, int arrayPosition, String key) {
		return jsonArray.getJSONObject(arrayPosition).getJSONObject(key);

	}
 	   	
 	   	public static String getStringFromJSONArray(JSONArray jsonArray,int arrayPosition, String key) {
 	      	 return jsonArray.getJSONObject(arrayPosition).get(key).toString();
 	   	
 	   	}
 	   	
 	   	
 	  	public static JSONObject getJSONObjectFromJSONArray(String jsonArrayString,int arrayPosition, String key) {
 	   		return getJSONObjectFromJSONArray(arrayStringToJsonArry(jsonArrayString),arrayPosition,key);
 	   	}
 	   	
 	   	public static String getStringFromJSONArray(String jsonArrayString,int arrayPosition, String key) {
 	   		return getStringFromJSONArray(arrayStringToJsonArry(jsonArrayString),arrayPosition,key);
 	    	}
 	   	
 		public static JSONArray arrayStringToJsonArry(String jsonArrayString) {
 			JSONArray jsonArray = new JSONArray(jsonArrayString);
 		
 			return jsonArray;
 		}
 		
 	   	public static String customFileName(MultipartFile file, String customFileName) {
 	   		return customFileName + "."
 	   				+ file.getOriginalFilename().substring(file.getOriginalFilename().lastIndexOf(".") + 1);
 	   	}

}
