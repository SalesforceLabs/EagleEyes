@isTest
public class Test_GetEventLogs {
    static testmethod void  testGetEventLogs(){
        Test.StartTest();    
         //Call the static method directly
        GetEventLogs.execute(null);
        list<String> listbodyStr= new list<string>();
        listbodyStr.add('"EVENT_TYPE","TIMESTAMP"');
         listbodyStr.add('"EVENT_TYPE","TIMESTAMP"');
        GetEventLogs g =new GetEventLogs();
     	GetEventLogs.trimQuotes(listbodyStr);
        system.assertEquals( GetEventLogs.trimQuotesForString('"EVENT_TYPE","TIMESTAMP"'), 'EVENT_TYPE,TIMESTAMP');
        GetEventLogs.printListHelper(listbodyStr);
        system.schedule ('Test GetEventLogs Hourly','0 10 * * * ?', new GetEventLogs() );
        Test.stopTest();
    }
}