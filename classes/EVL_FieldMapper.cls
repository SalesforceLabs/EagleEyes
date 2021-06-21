/*
** Convert fieldNames that has same meaning into the EventMonitoringRecord's field
** Examples:
**   BULK's success -> STATUS_CODE
**   API, REST's ENTITY_NAME, BUlk's ENTITY_TYPE, LEX's PAGE_ENTITY_TYPE => ENTITY_NAME
**   API's METHOD_NAME, Rest's METHOD, BULK's OPERATION_TYPE, VF's HTTP_METHOD => METHOD
*/
public class EVL_FieldMapper {
    // TODO any better way to map??
    private static Map<String, String> FIELD_MAP;
    
    private EVL_FieldMapper() { 
    }
    
    static {
        FIELD_MAP = new Map<String, String>();
        FIELD_MAP.put('browser_type', 'browser_name');  // Login
        FIELD_MAP.put('method_name', 'method'); // API, ApexSoap
        FIELD_MAP.put('api_type', 'request_type');  // API
        FIELD_MAP.put('url', 'uri');    // ApexCallout
        FIELD_MAP.put('success', 'request_status'); // ApexCallout
        FIELD_MAP.put('time', 'run_time');  // ApexCallout
        FIELD_MAP.put('class_name', 'entry_point'); // ApexSoap
        FIELD_MAP.put('trigger_name', 'entry_point');   // ApexTrigger
        FIELD_MAP.put('trigger_type', 'method');    // ApexSoap 
        FIELD_MAP.put('request_uri', 'entry_point');   // ConcurrentLongRunningApexLimit
        FIELD_MAP.put('operation_type', 'method'); // Bulk
        FIELD_MAP.put('http_method', 'method'); // VF
        FIELD_MAP.put('page_name', 'uri');  // VF
        FIELD_MAP.put('entity_type', 'entity_name');    // BUlk
        FIELD_MAP.put('page_entity_type', 'entity_name');   // LEX
        FIELD_MAP.put('prefixes_searched', 'entity_name');  // Search
        FIELD_MAP.put('num_results', 'rows_processed'); // Search
        FIELD_MAP.put('search_query', 'query'); // Search
        FIELD_MAP.put('page_url', 'uri');   // LEX
        FIELD_MAP.put('effective_page_time', 'run_time');   // LEX
   
    
        
    }
    
    //private Map<String, String> loadFielMappings() {  
    //}
    
    public static Boolean canConvertName(String input) {
        //System.debug('??? canConvertName: ' + input + FIELD_MAP.containsKey(input));
        return FIELD_MAP.containsKey(input);
    }
    
    public static String getConvertedName(String input) {
        return FIELD_MAP.get(input);
    }

}