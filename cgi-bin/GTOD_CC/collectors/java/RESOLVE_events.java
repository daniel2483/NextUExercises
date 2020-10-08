import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;


public class RESOLVE_events {

    public static void main(String[] args) throws IOException, SQLException, NullPointerException {

        HashMap <String,String> cfg = readCfg.ReadKmmCfg();
        File statText = new File(cfg.get("RAW_CACHE_DIR") + "/raw_resolve_events");
        FileOutputStream is = new FileOutputStream(statText);
        OutputStreamWriter osw = new OutputStreamWriter(is);
        Writer w = new BufferedWriter(osw);
        String nLn = "\n";

        String sql_application = "SELECT Client as Customer, ReSolveLog as ResolveID,"
                  +"[KPE+ PEM Key Escalation Contact] as Contact,"
                  +"InitialPriority as Priority,RTOP, RTOPType,"
                  +"RTOPTriggerTime as RTOPTime, InitialBusinessImpact as InitialImpact,"
                  +"CurrentBusinessImpact as CurrentImpact,"
                  +"Alpha, EventDesc, IncidentStart, PriorityStart, IncidentEnd,"
                  +"PriorityEnd, Status, [Incident Duration] as IncDuration, "
                  +"[External Records / Incident IDs] as ExtRecords, "
                  +"[Impacted KPEs] as KPE, "
                  +"[Next Actions] as NextActions, "
                  +"[Event Resolution] as EventRes, "
                  +"[Event Root Cause] as EventRoot, "
                  +"[CM Engaged] as CmEngaged, [CM Notified] as CmNotified, [Incident Duration] as IncDuration "
                  +"FROM ResolveCommandCenterProd.dbo.OpsCenter";

        ResultSet rsDB1 = SQLConnect.ConnectSQL(cfg.get("RESOLVE_SERVER"),cfg.get("RESOLVE_SID"),cfg.get("RESOLVE_USER"),cfg.get("RESOLVE_PASSWORD"), sql_application);

        // ordering CSI application usage data
				while(rsDB1.next()) {
          if (rsDB1.getString("Customer") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("Customer").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("ResolveID") == null) {
            w.write("null~~~");
            } else {
              w.write(rsDB1.getString("ResolveID").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("Contact") == null) {
            w.write("null~~~");
            } else {
              w.write(rsDB1.getString("Contact").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("Priority") == null) {
            w.write("null~~~");
            } else {
              w.write(rsDB1.getString("Priority").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("RTOP") == null) {
            w.write("null~~~");
            } else {
              w.write(rsDB1.getString("RTOP").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("RTOPType") == null) {
            w.write("null~~~");
            } else {
              w.write(rsDB1.getString("RTOPType").toLowerCase() + "~~~");
            }
            if (rsDB1.getString("RTOPTime") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("RTOPTime").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("InitialImpact") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("InitialImpact").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("CurrentImpact") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("CurrentImpact").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("Alpha") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("Alpha").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("EventDesc") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("EventDesc").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("IncidentStart") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("IncidentStart").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("PriorityStart") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("PriorityStart").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("IncidentEnd") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("IncidentEnd").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("PriorityEnd") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("PriorityEnd").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("Status") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("Status").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("IncDuration") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("IncDuration").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("CmEngaged") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("CmEngaged").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("CmNotified") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("CmNotified").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("ExtRecords") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("ExtRecords").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("KPE") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("KPE").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("NextActions") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("NextActions").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("EventRes") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("EventRes").toLowerCase() + "~~~");
            }
          if (rsDB1.getString("EventRoot") == null) {
              w.write("null~~~");
            } else {
              w.write(rsDB1.getString("EventRoot").toLowerCase() + "~~~");
            }
            w.write(nLn);
    }
      w.close();
  }
}
