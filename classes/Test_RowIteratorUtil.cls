@isTest
public class Test_RowIteratorUtil  {
    
    static testmethod void  testRowIteratorUtil(){
    Test.StartTest();
        
		String QUOTE = '"';
        String bodyStr='"EVENT_TYPE","TIMESTAMP","REQUEST_ID","ORGANIZATION_ID","USER_ID","RUN_TIME","CPU_TIME","URI","SESSION_KEY","LOGIN_KEY","EXEC_TIME","DB_TOTAL_TIME","CALLOUT_TIME","NUMBER_SOQL_QUERIES","ENTRY_POINT","QUIDDITY","TIMESTAMP_DERIVED","USER_ID_DERIVED","CLIENT_IP","URI_ID_DERIVED"';
    	RowIteratorUtil iterator = new RowIteratorUtil(bodyStr, '\n', QUOTE);
	    system.assertEquals(iterator.hasNext(), true);
       	system.assert(iterator.next()==bodyStr);
        RowIteratorUtil test_iterator2 = new RowIteratorUtil(bodyStr);
        system.debug('This is what this is' + test_iterator2.Iterator());
        Test.stopTest();
    }
    }