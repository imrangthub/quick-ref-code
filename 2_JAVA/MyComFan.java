
import java.io.File;
import java.io.IOException;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.Blob;
import java.sql.SQLException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Iterator;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.BeanUtils;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonMappingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.type.TypeFactory;
import com.imranmadbar.core.pagination.DataTableRequest;
import com.imranmadbar.core.pagination.DataTableResults;



/**
 * @author MD IMRAN HOSSAIN
 */
public interface MyComFan {

	default Response getSuccessResponse(String message) {
		Response response = new Response();
		response.setSuccess(true);
		response.setMessage(message);
		return response;
	}

	default Response getSuccessResponse(String message, Response response) {
		response.setSuccess(true);
		response.setMessage(message);
		return response;
	}

	default Response getErrorResponse(String message) {
		Response response = new Response();
		response.setSuccess(false);
		response.setMessage(message);
		return response;
	}

	default Response getErrorResponse(String message, Response response) {
		response.setSuccess(false);
		response.setMessage(message);
		return response;
	}

	String SECURED_READ_SCOPE = "#oauth2.hasScope('read')";

	default String strsingleQuotation(String val) {
		String[] values = val.split(",");
		StringBuilder str = new StringBuilder();
		for (int j = 0; j < values.length; j++) {
			if (j > 0) {
				str.append(",");
			}
			String valuesPattern = "'";
			valuesPattern += values[j];
			valuesPattern += "'";
			str.append(valuesPattern);

		}
		return str.toString();
	}

	String SECURED_WRITE_SCOPE = "#oauth2.hasScope('write')";
	String SECURED_PATTERN = "/api/**";

	default <T> DataTableResults<T> dataTableResults(DataTableRequest<T> dtr, List<T> pFilterList, List<T> pList,
			Long totalRecord) {

		DataTableResults<T> dataTableResult = new DataTableResults<T>();
		dataTableResult.setDraw(dtr.getDraw());

		if (dtr.isGlobalSearch()) {
			dataTableResult.setData(pList);
		} else {
			dataTableResult.setData(pList);
		}

		if ((pList != null && pList.size() > 0)) {

			dataTableResult.setRecordsTotal(String.valueOf(totalRecord));

			if (dtr.getPaginationRequest().isFilterByEmpty()) {
				dataTableResult.setRecordsFiltered(String.valueOf(totalRecord));

			} else {
				dataTableResult.setRecordsFiltered(Integer.toString(pList.size()));
			}

		} else {
			dataTableResult.setRecordsTotal("0");
			dataTableResult.setRecordsFiltered("0");
		}

		return dataTableResult;

	}

	default <T> DataTableResults<T> dataTableResults(DataTableRequest<T> dtr, Long pFilterCount, List<T> pList,
			Long totalRecord) {

		DataTableResults<T> dataTableResult = new DataTableResults<T>();
		dataTableResult.setDraw(dtr.getDraw());

		if (dtr.isGlobalSearch()) {
			dataTableResult.setData(pList);
		} else {
			dataTableResult.setData(pList);
		}

		if ((pList != null && pList.size() > 0)) {

			dataTableResult.setRecordsTotal(String.valueOf(totalRecord));

			if (dtr.getPaginationRequest().isFilterByEmpty()) {
				dataTableResult.setRecordsFiltered(String.valueOf(totalRecord));

			} else {
				dataTableResult.setRecordsFiltered(Long.toString(pFilterCount));
			}

		} else {
			dataTableResult.setRecordsTotal("0");
			dataTableResult.setRecordsFiltered("0");
		}

		return dataTableResult;

	}

	@SuppressWarnings("unchecked")
	default <T> List<T> objectMapperReadArrayValue(String mapperArrStr, Class<T> clazz) {
		ObjectMapper objectMapper = new ObjectMapper();
		try {

			return (List<T>) objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
					.readValue(mapperArrStr, TypeFactory.defaultInstance().constructCollectionType(List.class, clazz));

		} catch (JsonParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (JsonMappingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		}
	}

	long salutationList = 1005l;

	default String buildStr(String str, Map<String, Object> map) {
		String replaceStr = str;
		for (Map.Entry<String, Object> entry : map.entrySet()) {
			if (entry.getValue() instanceof String) {
				replaceStr = replaceStr.replaceAll(entry.getKey(), strsingleQuotation(entry.getValue().toString()));
			} else {
				replaceStr = replaceStr.replaceAll(entry.getKey(), entry.getValue().toString());
			}

		}
		return replaceStr;
	}

	/**
	 * @param str
	 * @param searchStr
	 * @return
	 */
	default boolean containsIgnoreCase(String str, String searchStr) {
		if (str != null) {
			return str.toLowerCase().contains(searchStr.toLowerCase());
		} else {
			return false;
		}

	}

	/**
	 * @param length
	 * @return long
	 */

	default long generateRandom(int length) {
		while (true) {
			long numb = (long) (Math.random() * 100000000 * 1000000);
			if (String.valueOf(numb).length() == length)
				return numb;
		}
	}

	default Map<String, Date> baseOnCriteriaFromAndToDate(Map<String, Object> dateRange) {
		Map<String, Date> formDateAndToDate = new HashMap<String, Date>();
		Date fromDate = null;
		Date toDate = null;
		if (DateRangCriteria.DATE_BETWEEN.name().equals(dateRange.get("dateRange"))) {
			fromDate = (Date) dateRange.get("fromDate");
			toDate = (Date) dateRange.get("toDate");
		} else if (DateRangCriteria.TODAY.name().equals(dateRange.get("dateRange"))) {
			fromDate = clearTime(new Date());
			toDate = oneDayPlusClearTime(new Date());
		} else if (DateRangCriteria.THIS_WEEK.name().equals(dateRange.get("dateRange"))) {
			fromDate = thisWeekFirstDate(null);
			toDate = thisWeekLastDate(null);
		} else if (DateRangCriteria.THIS_MONTH.name().equals(dateRange.get("dateRange"))) {
			fromDate = thisMonthFirstDate(null);
			toDate = thisMonthLastDate(null);
		} else if (DateRangCriteria.THIS_YEAR.name().equals(dateRange.get("dateRange"))) {
			fromDate = thisYearFirstDate();
			toDate = thisYearLastDate();
		} else {
			fromDate = clearTime(new Date());
			toDate = oneDayPlusClearTime(new Date());
		}

		formDateAndToDate.put("fromDate", fromDate);
		formDateAndToDate.put("toDate", toDate);
		return formDateAndToDate;
	}

	default Date thisWeekFirstDate(Date date) {
		Calendar cal = Calendar.getInstance();
		if (date != null) {
			cal.setTime(date);
		} else {
			cal.setTime(new Date());
		}
		cal.set(Calendar.DAY_OF_WEEK, cal.getActualMinimum(Calendar.DAY_OF_WEEK));
		return cal.getTime();
	}

	default Date thisWeekLastDate(Date date) {
		Calendar calendar = Calendar.getInstance();
		if (date != null) {
			calendar.setTime(date);
		} else {
			calendar.setTime(new Date());
		}
		calendar.set(Calendar.DAY_OF_WEEK, 7);
		return calendar.getTime();
	}

	default Date thisMonthFirstDate(Date date) {
		Calendar cal = Calendar.getInstance();
		if (date != null) {
			cal.setTime(date);
		} else {
			cal.setTime(new Date());
		}
		cal.set(Calendar.DAY_OF_MONTH, cal.getActualMinimum(Calendar.DAY_OF_MONTH));
		return cal.getTime();
	}

	default Date thisMonthLastDate(Date date) {
		Calendar calendar = Calendar.getInstance();
		if (date != null) {
			calendar.setTime(date);
		} else {
			calendar.setTime(new Date());
		}
		calendar.add(Calendar.MONTH, 1); // add one month
		calendar.set(Calendar.DAY_OF_MONTH, 1); // set value day 1
		calendar.add(Calendar.DATE, -1); // minus one date
		return calendar.getTime();
	}

	/**
	 * @param filePath
	 * @return
	 */
	public static File getresoucefile(String filePath) {
		Resource resource = new ClassPathResource(filePath);
		try {
			return resource.getFile();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return null;
	}

	default Date thisYearFirstDate() {
		// Current Date
		LocalDate currentDate = LocalDate.now();
		LocalDate date = LocalDate.of(currentDate.getYear(), 01, 01);
		Date thisYearFirstDate = null;
		try {
			thisYearFirstDate = new SimpleDateFormat("yyyy-MM-dd").parse(date.toString());
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return thisYearFirstDate;
	}

	default Date thisYearLastDate() {
		// Current Date
		LocalDate currentDate = LocalDate.now();
		LocalDate date = LocalDate.of(currentDate.getYear(), 12, 31);
		Date thisYearLastDate = null;
		try {
			thisYearLastDate = new SimpleDateFormat("yyyy-MM-dd").parse(date.toString());
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return thisYearLastDate;
	}

	/**
	 * @param file
	 * @return
	 */
	public static byte[] getResouceFileByte(File file) {

		try {
			return FileUtils.readFileToByteArray(file);
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return null;
	}
	
	/**
	 * @param string
	 * @return
	 */
	default String stringToBase64Decode(String param) {

		byte[] decodedBytes = Base64.getDecoder().decode(param);
		
		return new String(decodedBytes);
	}
	
	
	/**
	 * @param string
	 * @return
	 */
	default String stringToBase64Encode(String param) {

		return Base64.getEncoder().encodeToString(param.getBytes());
	}
	

	/**
	 * @param fileByte
	 * @return
	 */
	default String bytesToBase64String(byte[] fileByte) {

		return Base64.getEncoder().encodeToString(fileByte);
	}

	default Date oneDayPlus(Date date) {
		Date givenDate = date;
		LocalDate localDate = givenDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();

		Date oneDayPlusDate = null;
		try {
			oneDayPlusDate = new SimpleDateFormat("yyyy-MM-dd").parse(localDate.plusDays(1).toString());

		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return oneDayPlusDate;
	}

	default Date minusNDay(Date date, int day) {
		Date givenDate = date;
		LocalDate localDate = givenDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();

		Date oneDayPlusDate = null;
		try {
			oneDayPlusDate = new SimpleDateFormat("yyyy-MM-dd").parse(localDate.minusDays(day).toString());

		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return oneDayPlusDate;
	}

	default Date oneDayPlusClearTime(Date date) {
		Date givenDate = date;
		LocalDateTime localDateTime = givenDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDateTime();
		Date oneDayPlusDate = Date.from(localDateTime.plusDays(1).atZone(ZoneId.systemDefault()).toInstant());
		return oneDayPlusDate;
	}

	default Date clearTime(Date date) {
		Date givenDate = date;
		LocalDate localDate = givenDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
		Date localDateClearTime = null;
		try {
			localDateClearTime = new SimpleDateFormat("yyyy-MM-dd").parse(localDate.toString());
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return localDateClearTime;
	}

	default Date deateParse(String dateStr, String dateFormat) {

		Date parseDate = null;

		try {
			parseDate = new SimpleDateFormat(dateFormat).parse(dateStr);
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		return parseDate;
	}

	default String dateFormat(Date date, String dateFormat) {
		String parseDate = new SimpleDateFormat(dateFormat).format(date);
		return parseDate;
	}

	/*
	 * default List<PrescriptionDetailsEntity>
	 * getDetailList(List<PrescriptionDetailsEntity> presDetailList, int dataTypeid
	 * ){
	 * 
	 * return presDetailList.stream().filter(pd -> pd.getPrescritionDataType() ==
	 * dataTypeid).collect(Collectors.toList()); }
	 * 
	 * default PrescriptionDetailsEntity getDatil(List<PrescriptionDetailsEntity>
	 * presDetailList, int dataTypeid ){
	 * 
	 * return presDetailList.stream().filter(pd -> pd.getPrescritionDataType() ==
	 * dataTypeid).findFirst().orElse(null); }
	 */

	default BigDecimal convertLongToBigDecimmal(Long logval) {

		if (logval != null) {

			return new BigDecimal(logval);
		}

		return null;
	}

	default BigDecimal convertIntToBigDecimmal(Integer logval) {

		if (logval != null) {

			return new BigDecimal(logval);
		}

		return null;
	}

	default BigDecimal convertFloatToBigDecimmal(Float floatgval) {

		if (floatgval != null) {

			return new BigDecimal(floatgval);
		}

		return null;
	}

	default BigDecimal convertDoubleToBigDecimmal(Double doubleVal) {

		if (doubleVal != null) {

			return new BigDecimal(doubleVal);
		}

		return null;
	}

	default String objectToJson(Object content) {
		ObjectMapper objectMapper = new ObjectMapper();
		try {
			return objectMapper.writeValueAsString(content);

		} catch (JsonParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (JsonMappingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		}
		// return null;
	}

	default String procedureQuery(String procedureName, int procedureLength) {

		StringBuilder procdureCall = new StringBuilder();
		procdureCall.append("{call ");
		procdureCall.append(procedureName);
		procdureCall.append("(");

		int totalLenght = procedureLength;

		for (int i = 0; i < totalLenght; i++) {
			procdureCall.append("?");
			if (i != totalLenght - 1) {
				procdureCall.append(",");
			}
		}

		procdureCall.append(")}");

		return procdureCall.toString();
	}

	default Date addHourMinutesSeconds(int hour, int minute, int second, Date date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date);

		calendar.set(Calendar.HOUR_OF_DAY, 0);
		calendar.set(Calendar.MINUTE, 0);
		calendar.set(Calendar.SECOND, 0);

		calendar.add(Calendar.HOUR_OF_DAY, hour);
		calendar.add(Calendar.MINUTE, minute);
		calendar.add(Calendar.SECOND, second);

		return calendar.getTime();
	}

	default String imageBase64(byte[] imageValue) {

		if (imageValue != null) {

			return Base64.getEncoder().encodeToString(imageValue);
		}

		return null;
	}

	default String imageBase64(Blob imageValue) {

		return imageBase64(blobToByteArray(imageValue));

	}

	default byte[] blobToByteArray(Blob imgBlob) {

		byte[] imageBytes = null;

		try {
			imageBytes = imgBlob.getBytes(1, (int) imgBlob.length());
			return imageBytes;

		} catch (SQLException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return imageBytes;
		}

	}

	default <T> T objectMapperReadValue(String content, Class<T> valueType) {
		ObjectMapper objectMapper = new ObjectMapper();
		try {

			return objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false).readValue(content,
					valueType);

		} catch (JsonParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (JsonMappingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		}
		// return null;
	}

	// lookup detail related
	long prefixLookupNo = 5033l;
	long unitsLookupNo = 5032l;
	long eligibilityLookupNo = 5036l;
	long serviceCategoryLookupNo = 5031l;
	long personCategoryLookupNo = 5037l;
	long rankLookupNo = 5038l;
	long corpsLookupNo = 5039l;
	long nationalityLookupNo = 5041l;
	long priorityLookupNo = 5047l;
	long bloodGroupLookupNo = 1004l;
	long maritalStatusLookupNo = 1084l;
	long religionLookupNo = 1006l;
	long medicalCategoryLookupNo = 5040l;
	long districtLookupNo = 1001l;
	long relationListNo = 1021l;
	long familyLookupNo = 5044l;
	long cneLookupNo = 5045l;
	long reLookupNo = 5046l;
	long jobTypeNo = 1015l;
	long employeeTypeNo = 1007l;
	long hrTypeNo = 1014l;
	long upazilaLookupNo = 5043l;
	long countryLookupNo = 1002l;
	long genderList = 5007l;
	long patientCondition = 1074L;
	long arrivalCondition = 1072L;
	long arrivalMode = 1075L;
	long accompainedBy = 1076L;

	long physicalTherapy = 1204L;
	long theraputicExcercise = 1205L;

	default <T> T objectMapperReadValueWithDate(String content, Class<T> valueType) {
		ObjectMapper objectMapper = new ObjectMapper();
		objectMapper.setDateFormat(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.S"));
		try {

			return objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false).readValue(content,
					valueType);

		} catch (JsonParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (JsonMappingException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return null;
		}
		// return null;
	}

	@SuppressWarnings("unchecked")
	default <T> List<T> getListFromObject(Object data, Class<T> clazz) {

		if (data == null) {
			return null;
		}

		return (List<T>) data;
	}

	@SuppressWarnings("unchecked")
	default <T> T getValueFromObject(Object data, Class<T> clazz) {
		if (data == null) {
			return null;
		}
		return (T) data;
	}

	default String convertImageToBase64(String filePath) {
		File file = getresoucefile(filePath);
		byte[] bytes = getResouceFileByte(file);
		return bytesToBase64String(bytes);
	}

	default Date getYear(Date dateParam) {
		// return deateParse(dateFormat(dateParam, "yyyy"),"yyyy");
		LocalDate Ldate = LocalDate.of(Integer.parseInt(dateFormat(dateParam, "yyyy")), 0, 0);

		Date date = Date.from(Ldate.atStartOfDay(ZoneId.systemDefault()).toInstant());

		return date;

	}

	default Date thisYearFirstDate(Date date) {

		Calendar calendar = Calendar.getInstance();

		if (date != null) {
			calendar.setTime(date);
		} else {
			calendar.setTime(new Date());
		}
		calendar.set(Calendar.MONTH, 0);
		calendar.set(Calendar.DAY_OF_MONTH, 1);

		return clearTime(calendar.getTime());
	}

	default Date thisYearLastDate(Date date) {

		Calendar calendar = Calendar.getInstance();

		if (date != null) {
			calendar.setTime(date);
		} else {
			calendar.setTime(new Date());
		}
		calendar.set(Calendar.MONTH, 11);
		calendar.set(Calendar.DAY_OF_MONTH, 31);

		return clearTime(calendar.getTime());
	}

	default Date addMinTime(Date date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date);

		calendar.set(Calendar.HOUR_OF_DAY, 0);
		calendar.set(Calendar.MINUTE, 0);
		calendar.set(Calendar.SECOND, 0);
		calendar.set(Calendar.MILLISECOND, 0);

		return calendar.getTime();
	}

	default Date addMaxTime(Date date) {
		Calendar calendar = Calendar.getInstance();
		calendar.setTime(date);

		calendar.set(Calendar.HOUR_OF_DAY, 23);
		calendar.set(Calendar.MINUTE, 59);
		calendar.set(Calendar.SECOND, 59);
		calendar.set(Calendar.MILLISECOND, 999);

		return calendar.getTime();
	}

	default boolean isNullOrEmptyOrBlank(String str) {
		return null == str || str.isEmpty() || StringUtils.isBlank(str);
	}

	default java.sql.Date javaUtilDateToSqlDate(java.util.Date date) {
		return new java.sql.Date(date.getTime());
	}

	default java.util.Date javaSqlDateToUtilDate(java.sql.Date date) {
		return new java.util.Date(date.getTime());
	}

	default String getddmmyyyhhmmss() {
		return new SimpleDateFormat("ddmmyyyhhmmss").format(new Date());
	}

	default String getRandomNumber() {
		// It will generate 6 digit random Number.
		// from 0 to 999999
		Random rnd = new Random();
		int number = rnd.nextInt(999999);
		// this will convert any number sequence into 6 character.
		return String.format("%06d", number);
	}

	default boolean isParsableNumber(String strNumber) {

		boolean result = true;
		try {
			Long.parseLong(strNumber.trim());
		} catch (NumberFormatException exception) {
			result = false;
		}
		return result;
	}

	/**
	 * @param sourceObj
	 * @param targetClazz
	 */
	default void copyPropertiesEntityToDto(Object sourceObj, Object targetClazz) {
		BeanUtils.copyProperties(sourceObj, targetClazz);
	}

	/**
	 * @param sourceObj
	 * @param targetClazz
	 * @return
	 */
	@SuppressWarnings("unchecked")
	default <T> T copyPropertiesEntityToDto(Object sourceObj, Class<T> targetClazz) {
		Object clazzInstance = null;
		try {
			clazzInstance = targetClazz.newInstance();
			BeanUtils.copyProperties(sourceObj, clazzInstance);
		} catch (InstantiationException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IllegalAccessException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		return (T) clazzInstance;

	}

	/**
	 * @param sourceObj
	 * @param targetClazz
	 * @return
	 */
	@SuppressWarnings("rawtypes")
	default <T> List copyPropertiesEntityListToDtoList(List sourceList, Class<T> targetClazz) {

		List<T> arrangedList = new ArrayList<>();

		for (int i = 0; i < sourceList.size(); i++) {

			arrangedList.add(copyPropertiesEntityToDto(sourceList.get(i), targetClazz));
		}

		return arrangedList;
	}

	default String convertListToStringByCommaSeparetor(List ids) {

		if (ids != null && ids.size() > 0) {

			return StringUtils.join(ids, ",");
		}

		return null;
	}

	default Map<String, Object> readPassportJsonFile(String fileName) {

		Map<String, Object> _mp = new HashMap<String, Object>();
		//Map<String, Object> _attribute = null;

		try {

			String text = new String(Files.readAllBytes(Paths.get(fileName)), StandardCharsets.UTF_8);

			JSONObject json = Def.getJSONObject(text);
			String data = Def.getString(json, "data");
			JSONObject json2 = Def.getJSONObject(data);

			String token_url = Def.getString(json2, "token_url");
			String token_detail_url = Def.getString(json2, "token_detail_url");
			
			String _atttributes = Def.getString(json2, "token_request_attributes");

			JSONObject json3 = Def.getJSONObject(_atttributes);
			
			String body = Def.getString(json3, "BODY");
			
			JSONObject json4 = Def.getJSONObject(body);
			
			String api_client_id = Def.getString(json4, "api_client_id");
			String secret_code = Def.getString(json4, "secret_code");
		

			_mp.put("token_url", token_url);
			_mp.put("token_detail_url", token_detail_url);
			_mp.put("api_client_id", api_client_id);
			_mp.put("secret_code", secret_code);

		} catch (Exception ex) {
			System.out.println(ex.toString());
		}
		return _mp;
	}

	default Map<String, Object> jsonToMap(JSONObject json) {
		Map<String, Object> retMap = new HashMap<String, Object>();

		if (json != JSONObject.NULL) {
			retMap = toMap(json);
		}
		return retMap;
	}

	default Map<String, Object> toMap(JSONObject object) throws JSONException {
		Map<String, Object> map = new HashMap<String, Object>();

		Iterator<String> keysItr = object.keySet().iterator();
		while (keysItr.hasNext()) {
			String key = keysItr.next();
			Object value = object.get(key);

			if (value instanceof JSONObject) {
				value = toMap((JSONObject) value);
			}
			map.put(key, value);
		}
		return map;
	}
	
    default String loadPassportJson(){
 	   
 	   ClassLoader classLoader = getClass().getClassLoader();
 	   File file = new File(classLoader.getResource("passport-kiosk-api.json").getFile());
 	   String absolutePath = file.getAbsolutePath();
 	   
		   return absolutePath;
    }
    
	/* 
	1. ^ - From start of the string
	2. (?:\+?88)? - optional 88, which may begin in +
	3. 01 - mandatory 01
	4. [13-9] - "1 or 3 or 6 or 7 or 8 or 9"
	5. \d{8} - 8 digits
	6. $ - end of the string
	*/
	default boolean isValidPhoneNumber(String phoneNumber) {
	if(phoneNumber.matches("^(?:\\+?88|0088)?01[13-9]\\d{8}$")) {
	
		return true;
	};
	
	return false;
	}
	
	
	
  default Long findDifferenceTwoDate(Date date1, Date date2) {
		
		   long difference_In_Time = date1.getTime() - date2.getTime();
		   long hours   = (int) ((difference_In_Time / (1000*60*60)));
	
		 return hours;
	}
  
  
  default boolean strStartWithDigit(String str) {
	  return str.matches("^[0-9].*$");
  }
  
  default String randomAlphaNumeric(int count) {
	     
		String ALPHA__STRING = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        String NUMERIC_STRING = "0123456789";
     
	StringBuilder builder = new StringBuilder();
	
	while (count-- != 0) {
		
	if(count % 2 == 0) {
		int character = (int)(Math.random()*ALPHA__STRING.length());
		builder.append(ALPHA__STRING.charAt(character));
	}else {
		int character = (int)(Math.random()*NUMERIC_STRING.length());
		builder.append(NUMERIC_STRING.charAt(character));
	}	

	
	}
	return builder.toString();
	}
  
}
