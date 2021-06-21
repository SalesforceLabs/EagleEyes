global class GetEventLogs implements Schedulable {
    static final Integer BATCH_SIZE = 2000;
    static integer lastNDays = 1;
    static integer lastNHours = 1;
    static final String INTERVAL = 'Hourly';
    //Set<String> RECORD_FIELDS = new Set<String> {};
    //Boolean ifStoreAllFields = true;
    static final String DELIMITER = '","';
    static final String QUOTE = '"';

    static  Map<String,Set <String> > configDataMAP = new Map <String,Set <String>>();   //This contains the config data that gets created one time

    static  List<String> EVENT_TYPES = new List<String> {'API', 'BulkApi', 'RestApi', 'ApexCallout', 'ApexExecution', 'ApexSoap', 'ApexTrigger', 'VisualforceRequest', 'LightningPageView'}; // just backup managed by custom Metadata
    static  Set<String> SKIP_ENTITIES = new Set<String> {'IDEWorkspace', 'Layout', 'MetadataContainer', 'MetadataContainerMember', 'ObjectPermissions', 'Snapshot','LimitSnapshot','SetupApp','SetupNode', 'RecentlyViewed', 'TabSet', 'OverridableEntities', 'UserPreference'}; // just backup managed by custom Metadata
    static  Set<String> INCLUDE_ENTITIES = new Set<String> {'Account', 'Contact', 'Lead', 'Opportunity', 'Quote', 'Campaign', 'Task', 'Event', 'Case', 'User'}; // just backup managed by custom Metadata

    static final String BULK_URI = 'BULKAPI-LOG';
    static Map<String, Schema.SObjectField> objectFieldsMap = null; // TODO map of DescribeFieldResult?
    // static final IConverter converter;
    static String namespacePrefix;
    
    public static void execute(SchedulableContext SC) {

        getconfigData(); //loading config data

        if(configDataMAP.containsKey('EVENT_TYPES'))
        {
            EVENT_TYPES.clear();
            EVENT_TYPES.addAll(configDataMAP.get('EVENT_TYPES'));
        }
        
        if(configDataMAP.containsKey('SKIP_ENTITIES'))
        {
            SKIP_ENTITIES.clear();
            SKIP_ENTITIES.addAll(configDataMAP.get('SKIP_ENTITIES'));
        }

        if(configDataMAP.containsKey('INCLUDE_ENTITIES'))
        {
            INCLUDE_ENTITIES.clear();
            INCLUDE_ENTITIES.addAll(configDataMAP.get('INCLUDE_ENTITIES'));
        }

        if (test.isRunningTest())
         {
            EVENT_TYPES = new List<String> {'API', 'BulkApi', 'RestApi', 'ApexCallout', 'ApexExecution', 'ApexSoap', 'ApexTrigger', 'VisualforceRequest', 'LightningPageView'};
            INCLUDE_ENTITIES = new Set<String> {'Account', 'Contact', 'Lead', 'Opportunity', 'Quote', 'Campaign', 'Task', 'Event', 'Case', 'User'};
        }
        ApexClass ac = [SELECT NamespacePrefix FROM ApexClass WHERE Name = 'GetEventLogs' LIMIT 1];
        namespacePrefix = ac.NamespacePrefix.tolowercase() + '__';
        
        Datetime dT; 
        if (INTERVAL.equals('Hourly')) {
            dT = System.now().addHours(-lastNHours);
            // System.debug(dT);
        } else {
            dT = System.now().addDays(-lastNDays);
            dT = date.newInstance(dT.year(), dT.month(), dT.day());
        }
               
        List<EventLogFile> logfiles = new List<EventLogFile>();
        
        // System.debug(filterDate);
        

       
        String soql = 'SELECT LogDate, EventType, LogFile, Sequence, LogFileLength FROM EventLogFile WHERE CreatedDate >= :dT AND Interval =:INTERVAL AND EventType IN :EVENT_TYPES AND LogFileLength < 6000000';
        if (test.isRunningTest())
         {
             soql = 'SELECT LogDate, EventType, LogFile, Sequence, LogFileLength FROM EventLogFile limit 10';
         }
        logfiles = Database.query(soql);
        if (!logfiles.isEmpty()) {
            objectFieldsMap = getFieldsMap();
            for (EventLogFile f : logfiles) {
              //  System.debug('===== Processing ' + f.EventType + ' on ' + f.LogDate + ', size: ' + f.LogFileLength + ' =====');
              if(f.LogFileLength<6000000 )
              {
                extractLogsFromSingleFile(f.LogFile);
              }
            }
        }
    }
    
    static Map<String, Schema.SObjectField> getFieldsMap() {
        if (objectFieldsMap == null) {
            objectFieldsMap = Schema.SObjectType.EventMonitoringRecord__c.fields.getMap();
        }
        return objectFieldsMap;
    }

   public static void getconfigData() // this is the config data from the custom metadata to avoid hard coding
    {
        for (Performance_Dashboard_configs__mdt configData : [SELECT MasterLabel,DeveloperName FROM FScalePerf__Performance_Dashboard_configs__mdt where FScalePerf__Is_Active__c = true]) {
            if(configDataMAP.containsKey(configData.MasterLabel)) 
            {
                configDataMAP.get(configData.MasterLabel).add(configData.DeveloperName);
            }
    
            else{
    
                configDataMAP.put(configData.MasterLabel, new set<string>{configData.DeveloperName});
    
            }
         
            }

    }
    
    private static void extractLogsFromSingleFile(Blob content) {
        String bodyStr = content.toString();
        // bodyStr = trimQuotesForString(bodyStr);
      //   System.debug(bodyStr);
        // List<String> rows = new List<String>();
        RowIteratorUtil iterator = new RowIteratorUtil(bodyStr, '\n', QUOTE);
        
        Map<String, Integer> fieldIndexMap = mapFieldsFromHeader(iterator.next().split(DELIMITER));
        system.debug('VV fieldmap'+ fieldIndexMap);
        Integer rowCount = 0;
        List<String> batchedRows = new List<String>();
        while (iterator.hasNext() && rowCount <= BATCH_SIZE) {
            String row = iterator.next();
            batchedRows.add(row);
            if (rowCount == BATCH_SIZE) {
                ExtractLogsFromSingleFileChunkQueueable extractQueuable = new ExtractLogsFromSingleFileChunkQueueable(objectFieldsMap, fieldIndexMap, batchedRows, namespacePrefix);
                System.enqueueJob(extractQueuable);
                rowCount = 0;
                batchedRows.clear();
            } else {
                rowCount++;
            }
        }
        // last chunk or the whole file is less than BATCH_SIZE
        ExtractLogsFromSingleFileChunkQueueable extractQueuable = new ExtractLogsFromSingleFileChunkQueueable(objectFieldsMap, fieldIndexMap, batchedRows, namespacePrefix);
        System.enqueueJob(extractQueuable);
        
    }
    
    /* <fieldName (including namespace, column index> */
    private static Map<String, Integer> mapFieldsFromHeader(List<String> header) {
        
        Map<String, Integer> fieldIndexMap = new Map<String, Integer>();
        fieldIndexMap.put(namespacePrefix + 'event_type__c', 0);
        for (Integer i = 1; i < header.size(); i++) {
            String headerName = header[i].toLowerCase();
            //system.debug('the Field to Map is:' +headerName);
            headerName= headerName.replace('"','');
            
            String fieldName = namespacePrefix + headerName + '__c';
            
            
            if (!objectFieldsMap.keySet().contains(fieldName)) {
               // system.Debug('====Filed Exists' + fieldName);
                // TODOs:
                // Rest.method -> method_name
                // Bulk.OPERATION_TYPE -> method_name
                // Bulk.Success -> request_status
                // Bulk.ENTITY_TYPE__c -> Entity_Name
                // APi_Type: p2
                // System.debug('@@@ field from logFile does not exist in objectFieldsMap: ' + fieldName + '. Trying EVL_FieldMapper...');
                // continue;
              
                
                if (EVL_FieldMapper.canConvertName(headerName)) {
                    fieldName = namespacePrefix + EVL_FieldMapper.getConvertedName(headerName) + '__c';
                    if (!objectFieldsMap.keySet().contains(fieldName)) {
                        // System.debug('@@@ field does not exist after convert. Check the mapping. ');
                        // header[i] = SKIP_COLUMN;
                        continue;
                    } else {
                        fieldIndexMap.put(fieldName, i);
                    }
                } else {
                    //System.debug('@@@ field from logFile does not exist in EVL_FieldMapper. Skipping field ' + fieldName);
                    // header[i] = SKIP_COLUMN;
                    continue;
                }
            } else {
                fieldIndexMap.put(fieldName, i);
            }
        }
       // system.debug('fieldIndexMap is ' + fieldIndexMap);
        return fieldIndexMap;
    }
    
    private static boolean isIncludedEntity(String content) {
        if (content.endsWithIgnoreCase('__c') || content.endsWithIgnoreCase('__e') || content.endsWithIgnoreCase('__x') )   return true; // don't skip custom obj
        if (content.endsWithIgnoreCase('Share'))    return false;
        if (INCLUDE_ENTITIES.contains(content)) return true;
        return (content.startsWith('Account') || content.startsWith('Opportunity'));
    }
    
   public static void trimQuotes(List<String> input) {
        for (integer i = 0; i < input.size(); i++) {
            input[i] = input[i].replace(QUOTE, '');
        }
    }
    
   public static String trimQuotesForString(String input) {
        return input.replace(QUOTE, '');
    }
    
 public static void printListHelper(List<String> listOfThings) {
        String tmp = '';
        for (String s : listOfThings) {
            tmp = tmp + s + ',';
        }
       // System.debug(tmp);
    }
    
    
    public class ExtractLogsFromSingleFileChunkQueueable implements Queueable {
        private Map<String, Integer> fieldIndexMap;  // <fieldname, column index>
        private List<String> batchedRows;
        private Map<String, Schema.SObjectField> objectFieldsMap;
        private final String namespacePrefix;
        
        public ExtractLogsFromSingleFileChunkQueueable(Map<String, Schema.SObjectField> objectFieldsMap, Map<String, Integer> fieldIndexMap, List<String> batchedRows, String namespacePrefix) {
            this.objectFieldsMap = objectFieldsMap;
            this.fieldIndexMap = fieldIndexMap;
            this.batchedRows = batchedRows;
            this.namespacePrefix = namespacePrefix;
        }
        
        public void execute(QueueableContext context) {
            List<EventMonitoringRecord__c> emr = new List<EventMonitoringRecord__c>();
            for (String row : batchedRows) {
                EventMonitoringRecord__c r = convertIntoSObject(fieldIndexMap, row.split(DELIMITER));
                if (r != null) {
                    emr.add(r);
                }
            }
            //System.debug('======= Total size: ' + emr.size());
          /*  for (EventMonitoringRecord__c r : emr) {
                System.debug(r);
            }*/
            insert emr;
        }
        
        private String timeToString(Integer value) {
            String str;
            if (value >= 10) {
                str = String.valueOf(value);
            } else {
                str = '0' + String.valueOf(value);
            }
            return str;
        }
        
        private EventMonitoringRecord__c convertIntoSObject(Map<String, Integer> header, List<String> row) {
            String eventType = row[header.get(namespacePrefix + 'event_type__c')].replace(QUOTE, '');            
            // Integer maxField = Math.min(header.size(), row.size());
            /* Some pre-filtering before loop over all fields */
            String tmpContent;
            if (eventType.equals('BulkApi')) {
                tmpContent = row[header.get(namespacePrefix + 'uri__c')].replace(QUOTE, '');
                  if (tmpContent.length() > 250) {
                                tmpContent= tmpContent.substring(0, 250);
                    }
                if (!tmpContent.equals(BULK_URI)) { // only uri__c = BULKAPI-LOG contains useful info (for now)
                    return null;
                }
            }
            if (eventType.containsIgnoreCase('Api')) {
                if(header.get(namespacePrefix + 'entity_name__c')!=null) {
                  tmpContent = row[header.get(namespacePrefix + 'entity_name__c')].replace(QUOTE, '');  // skip API request that has no entity info
                   if (tmpContent.length() > 250) {
                                tmpContent= tmpContent.substring(0, 250);
                    }
                }
                if (String.isBlank(tmpContent) || !isIncludedEntity(tmpContent)) {
                    return null;
                }    
                    
            }
            if (eventType.equals('ApexExecution')) {
                 if(header.get(namespacePrefix + 'entry_point__c')!=null)
                {
               
                tmpContent = row[header.get(namespacePrefix + 'entry_point__c')].replace(QUOTE, '');
               if (tmpContent.length() > 250) {
                                tmpContent= tmpContent.substring(0, 250);
                    }
               
                if (tmpContent.contains(GetEventLogs.class.getName())) {
                    return null;
                }
                     }
            }
            
            
            EventMonitoringRecord__c rec = new EventMonitoringRecord__c();
            rec.EVENT_TYPE__c = eventType; // TODO new field, event_type__c
            for (String fieldName : header.keySet()) {
                String content = row[header.get(fieldName)].replace(QUOTE, '');
                 if (content.length() > 250) {
                                content= content.substring(0, 250);
                    }
                if (String.isBlank(content)) {
                    continue;
                }
                Schema.SoapType fieldType = objectFieldsMap.get(namespacePrefix + fieldName).getDescribe().getSoapType();
                
              // system.debug('the field Name is :'+ fieldName);
                
                // TODO maybe change this into interface
                String datetimeStr = '';
                try {
                    if (fieldType == Schema.SoapType.DOUBLE) {
                        if (fieldName.equals(namespacePrefix + 'db_total_time__c')) {
                            rec.put(fieldName, (Double.valueOf(content))/1000000);  // original nanoseconds 
                        } else {
                            rec.put(fieldName, Double.valueOf(content));
                        }
                        
                    } else if (fieldType == Schema.SoapType.DATETIME) {
                        Datetime ts = (DateTime) JSON.deserialize('"' + content + '"', DateTime.class);
                        rec.put(fieldName, ts);
                        rec.put('TIMESTAMP_HOUR__c', timeToString(ts.hour()));
                        rec.put('TIMESTAMP_MINUTE__c', timeToString(ts.minute()));
                        rec.put('TIMESTAMP_SECOND__c', timeToString(ts.second()));
                        datetimeStr = content;
                    } else if (fieldType == Schema.SoapType.Boolean)
                    {
                            rec.put(fieldName, Boolean.valueOf(content));
                        

                    }else { // text, picklist etc
                            if (content.length() > 250) {
                                rec.put(fieldName, content.substring(0, 250));
                            }
                        
                        if (fieldName.equals(namespacePrefix + 'request_status__c')) {
                            if (content.equals('1'))    rec.put(fieldName, 'S');
                            else if (content.equals('0'))   rec.put(fieldName, 'S');
                            else    rec.put(fieldName, content);
                        } else if (fieldName.equals('Name') && content.length() > 80) {
                            rec.put(fieldName, content.substring(0, 70));
                        }else {
                            
                            if (fieldName.equals(namespacePrefix + 'message__c') && content.equals('success') && Integer.valueOf(row[header.get(namespacePrefix + 'number_failures__c')].replace(QUOTE, '')) > 0) {
                                rec.put(fieldName, 'Failure details unknown');  // message will be success if it's not due to locking?
                            } else {
                                rec.put(fieldName, content);
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Exception during rec.put: fieldName: ' + fieldName + ', content: ' + content);
                    throw e;
                }
                
                rec.put('Name', eventType + ' ' + datetimeStr);
            }
            
            return rec;
        }
        
    }
    

}