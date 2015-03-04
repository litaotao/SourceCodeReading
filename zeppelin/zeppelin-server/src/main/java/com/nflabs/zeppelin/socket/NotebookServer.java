package com.nflabs.zeppelin.socket;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.java_websocket.WebSocket;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;
import org.quartz.SchedulerException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Strings;
import com.google.gson.Gson;
/*
这里之所以能import 出zeppelin-zengine模块下面的com.nflabs.zeppelin.notebook包，
是因为zeppelin-server中的pom.xml文件明显指出zeppelin-server模块依赖于模块
zepplin-zengine。
//
import语句与C语言中的 #include 有些类似，语法为：
    import package1[.package2…].classname;
package 为包名，classname 为类名。
//
注意：
import 只能导入包所包含的类，而不能导入包。
为方便起见，我们一般不导入单独的类，而是导入包下所有的类，例如 import java.util.*;。
//
import路径：比如说语句 import com.nflabs.zeppelin.notebook.Note;
1. 先在当前目录下面递归查询是否有com.nflabs.zeppelin.notebook包；
2. 在$CLASSPATH下面递归查询com.nflabs.zeppelin.notebook包；
因为第一句 package com.nflabs.zeppelin.socket 所以 NotebookServer 这个class所在的当前路径是 com.nflabs.zeppelin.socket
*/
import com.nflabs.zeppelin.notebook.JobListenerFactory;
import com.nflabs.zeppelin.notebook.Note;
import com.nflabs.zeppelin.notebook.Notebook;
import com.nflabs.zeppelin.notebook.Paragraph;
import com.nflabs.zeppelin.scheduler.Job;
import com.nflabs.zeppelin.scheduler.Job.Status;
import com.nflabs.zeppelin.scheduler.JobListener;
import com.nflabs.zeppelin.server.ZeppelinServer;
import com.nflabs.zeppelin.socket.Message.OP;

/**
 * Zeppelin websocket service.
 *
 * @author anthonycorbacho
 */
/*
关于java里的extends和implements，可以参考：http://blog.csdn.net/chen_chun_guang/article/details/6323201
这里定义了一个类NotebookServer，它继承了类WebSocketServer，并实现了JobListenerFactory接口的方法。
*/
public class NotebookServer extends WebSocketServer implements JobListenerFactory {
/*
//关于访问控制
public  共有的，对所有类可见。
protected 受保护的，对同一包内的类和所有子类可见。
private 私有的，在同一类内可见。
默认的 在同一包内可见。默认不使用任何修饰符。
//关于final关键字
根据程序上下文环境，Java关键字final有“这是无法改变的”或者“终态的”含义，它可以修饰非抽象类、非抽象类成员方法和变量。你可能出于两种理解而需要阻止改变：设计或效率。
        final类不能被继承，没有子类，final类中的方法默认是final的。
        final方法不能被子类的方法覆盖，但可以被继承。
        final成员变量表示常量，只能被赋值一次，赋值后值不再改变。
        final不能用于修饰构造方法。
        注意：父类的private成员方法是不能被子类方法覆盖的，因此private类型的方法默认是final类型的。
//关于static关键字
static表示“全局”或者“静态”的意思，用来修饰成员变量和成员方法，也可以形成静态static代码块，但是Java语言中没有全局变量的概念。
被static修饰的成员变量和成员方法独立于该类的任何对象。也就是说，它不依赖类特定的实例，被类的所有实例共享。只要这个类被加载，
Java虚拟机就能根据类名在运行时数据区的方法区内定找到他们。因此，static对象可以在它的任何对象创建之前访问，无需引用任何对象。
*/
  private static final Logger LOG = LoggerFactory.getLogger(NotebookServer.class);
  private static final int DEFAULT_PORT = 8282;

  private static void creatingwebSocketServerLog(int port) {
    LOG.info("Create zeppelin websocket on port {}", port);
  }

  Gson gson = new Gson();
  Map<String, List<WebSocket>> noteSocketMap = new HashMap<String, List<WebSocket>>();
  List<WebSocket> connectedSockets = new LinkedList<WebSocket>();

  public NotebookServer() {
    super(new InetSocketAddress(DEFAULT_PORT));
    creatingwebSocketServerLog(DEFAULT_PORT);
  }

  public NotebookServer(int port) {
    super(new InetSocketAddress(port));
    creatingwebSocketServerLog(port);
  }

  private Notebook notebook() {
    return ZeppelinServer.notebook;
  }

  @Override
  public void onOpen(WebSocket conn, ClientHandshake handshake) {
    LOG.info("New connection from {} : {}", conn.getRemoteSocketAddress().getHostName(), conn
        .getRemoteSocketAddress().getPort());
    synchronized (connectedSockets) {
      connectedSockets.add(conn);
    }
  }

  @Override
  public void onMessage(WebSocket conn, String msg) {
    Notebook notebook = notebook();
    try {
      Message messagereceived = deserializeMessage(msg);
      LOG.info("RECEIVE << " + messagereceived.op);
      /** Lets be elegant here */
      switch (messagereceived.op) {
          case LIST_NOTES:
            broadcastNoteList();
            break;
          case GET_NOTE:
            sendNote(conn, notebook, messagereceived);
            break;
          case NEW_NOTE:
            createNote(conn, notebook);
            break;
          case DEL_NOTE:
            removeNote(conn, notebook, messagereceived);
            break;
          case COMMIT_PARAGRAPH:
            updateParagraph(conn, notebook, messagereceived);
            break;
          case RUN_PARAGRAPH:
            runParagraph(conn, notebook, messagereceived);
            break;
          case CANCEL_PARAGRAPH:
            cancelParagraph(conn, notebook, messagereceived);
            break;
          case MOVE_PARAGRAPH:
            moveParagraph(conn, notebook, messagereceived);
            break;
          case INSERT_PARAGRAPH:
            insertParagraph(conn, notebook, messagereceived);
            break;
          case PARAGRAPH_REMOVE:
            removeParagraph(conn, notebook, messagereceived);
            break;
          case NOTE_UPDATE:
            updateNote(conn, notebook, messagereceived);
            break;
          case COMPLETION:
            completion(conn, notebook, messagereceived);
            break;
          default:
            broadcastNoteList();
            break;
      }
    } catch (Exception e) {
      LOG.error("Can't handle message", e);
    }
  }

  @Override
  public void onClose(WebSocket conn, int code, String reason, boolean remote) {
    LOG.info("Closed connection to {} : {}", conn.getRemoteSocketAddress().getHostName(), conn
        .getRemoteSocketAddress().getPort());
    removeConnectionFromAllNote(conn);
    synchronized (connectedSockets) {
      connectedSockets.remove(conn);
    }
  }

  @Override
  public void onError(WebSocket conn, Exception message) {
    removeConnectionFromAllNote(conn);
    synchronized (connectedSockets) {
      connectedSockets.remove(conn);
    }
  }

  private Message deserializeMessage(String msg) {
    Message m = gson.fromJson(msg, Message.class);
    return m;
  }

  private String serializeMessage(Message m) {
    return gson.toJson(m);
  }

  private void addConnectionToNote(String noteId, WebSocket socket) {
    synchronized (noteSocketMap) {
      removeConnectionFromAllNote(socket); // make sure a socket relates only a single note.
      List<WebSocket> socketList = noteSocketMap.get(noteId);
      if (socketList == null) {
        socketList = new LinkedList<WebSocket>();
        noteSocketMap.put(noteId, socketList);
      }

      if (socketList.contains(socket) == false) {
        socketList.add(socket);
      }
    }
  }

  private void removeConnectionFromNote(String noteId, WebSocket socket) {
    synchronized (noteSocketMap) {
      List<WebSocket> socketList = noteSocketMap.get(noteId);
      if (socketList != null) {
        socketList.remove(socket);
      }
    }
  }

  private void removeNote(String noteId) {
    synchronized (noteSocketMap) {
      List<WebSocket> socketList = noteSocketMap.remove(noteId);
    }
  }

  private void removeConnectionFromAllNote(WebSocket socket) {
    synchronized (noteSocketMap) {
      Set<String> keys = noteSocketMap.keySet();
      for (String noteId : keys) {
        removeConnectionFromNote(noteId, socket);
      }
    }
  }

  private String getOpenNoteId(WebSocket socket) {
    String id = null;
    synchronized (noteSocketMap) {
      Set<String> keys = noteSocketMap.keySet();
      for (String noteId : keys) {
        List<WebSocket> sockets = noteSocketMap.get(noteId);
        if (sockets.contains(socket)) {
          id = noteId;
        }
      }
    }
    return id;
  }

  private void broadcast(String noteId, Message m) {
    LOG.info("SEND >> " + m.op);
    synchronized (noteSocketMap) {
      List<WebSocket> socketLists = noteSocketMap.get(noteId);
      if (socketLists == null || socketLists.size() == 0) {
        return;
      }
      for (WebSocket conn : socketLists) {
        conn.send(serializeMessage(m));
      }
    }
  }

  private void broadcastAll(Message m) {
    synchronized (connectedSockets) {
      for (WebSocket conn : connectedSockets) {
        conn.send(serializeMessage(m));
      }
    }
  }

  private void broadcastNote(Note note) {
    broadcast(note.id(), new Message(OP.NOTE).put("note", note));
  }

  private void broadcastNoteList() {
    Notebook notebook = notebook();
    List<Note> notes = notebook.getAllNotes();
    List<Map<String, String>> notesInfo = new LinkedList<Map<String, String>>();
    for (Note note : notes) {
      Map<String, String> info = new HashMap<String, String>();
      info.put("id", note.id());
      info.put("name", note.getName());
      notesInfo.add(info);
    }
    broadcastAll(new Message(OP.NOTES_INFO).put("notes", notesInfo));
  }

  private void sendNote(WebSocket conn, Notebook notebook, Message fromMessage) {
    String noteId = (String) fromMessage.get("id");
    if (noteId == null) {
      return;
    }
    Note note = notebook.getNote(noteId);
    if (note != null) {
      addConnectionToNote(note.id(), conn);
      conn.send(serializeMessage(new Message(OP.NOTE).put("note", note)));
    }
  }

  private void updateNote(WebSocket conn, Notebook notebook, Message fromMessage)
      throws SchedulerException, IOException {
    String noteId = (String) fromMessage.get("id");
    String name = (String) fromMessage.get("name");
    Map<String, Object> config = (Map<String, Object>) fromMessage.get("config");
    if (noteId == null) {
      return;
    }
    if (config == null) {
      return;
    }
    Note note = notebook.getNote(noteId);
    if (note != null) {
      boolean cronUpdated = isCronUpdated(config, note.getConfig());
      note.setName(name);
      note.setConfig(config);

      if (cronUpdated) {
        notebook.refreshCron(note.id());
      }
      note.persist();
      
      broadcastNote(note);
      broadcastNoteList();
    }
  }

  private boolean isCronUpdated(Map<String, Object> configA, Map<String, Object> configB) {
    boolean cronUpdated = false;
    if (configA.get("cron") != null && configB.get("cron") != null
        && configA.get("cron").equals(configB.get("cron"))) {
      cronUpdated = true;
    } else if (configA.get("cron") == null && configB.get("cron") == null) {
      cronUpdated = false;
    } else if (configA.get("cron") != null || configB.get("cron") != null) {
      cronUpdated = true;
    }
    return cronUpdated;
  }

  private void createNote(WebSocket conn, Notebook notebook) throws IOException {
    Note note = notebook.createNote();
    note.addParagraph(); // it's an empty note. so add one paragraph
    note.persist();
    broadcastNote(note);
    broadcastNoteList();
  }

  private void removeNote(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    String noteId = (String) fromMessage.get("id");
    if (noteId == null) {
      return;
    }
    Note note = notebook.getNote(noteId);
    note.unpersist();
    notebook.removeNote(noteId);
    removeNote(noteId);
    broadcastNoteList();
  }

  private void updateParagraph(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    String paragraphId = (String) fromMessage.get("id");
    if (paragraphId == null) {
      return;
    }
    Map<String, Object> params = (Map<String, Object>) fromMessage.get("params");
    Map<String, Object> config = (Map<String, Object>) fromMessage.get("config");
    final Note note = notebook.getNote(getOpenNoteId(conn));
    Paragraph p = note.getParagraph(paragraphId);
    p.settings.setParams(params);
    p.setConfig(config);
    p.setTitle((String) fromMessage.get("title"));
    p.setText((String) fromMessage.get("paragraph"));
    note.persist();
    broadcast(note.id(), new Message(OP.PARAGRAPH).put("paragraph", p));
  }

  private void removeParagraph(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    final String paragraphId = (String) fromMessage.get("id");
    if (paragraphId == null) {
      return;
    }
    final Note note = notebook.getNote(getOpenNoteId(conn));
    /** We dont want to remove the last paragraph */
    if (!note.isLastParagraph(paragraphId)) {
      note.removeParagraph(paragraphId);
      note.persist();
      broadcastNote(note);
    }
  }

  private void completion(WebSocket conn, Notebook notebook, Message fromMessage) {
    String paragraphId = (String) fromMessage.get("id");
    String buffer = (String) fromMessage.get("buf");
    int cursor = (int) Double.parseDouble(fromMessage.get("cursor").toString());
    Message resp = new Message(OP.COMPLETION_LIST).put("id", paragraphId);

    if (paragraphId == null) {
      conn.send(serializeMessage(resp));
      return;
    }

    final Note note = notebook.getNote(getOpenNoteId(conn));
    List<String> candidates = note.completion(paragraphId, buffer, cursor);
    resp.put("completions", candidates);
    conn.send(serializeMessage(resp));
  }

  private void moveParagraph(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    final String paragraphId = (String) fromMessage.get("id");
    if (paragraphId == null) {
      return;
    }

    final int newIndex = (int) Double.parseDouble(fromMessage.get("index").toString());
    final Note note = notebook.getNote(getOpenNoteId(conn));
    note.moveParagraph(paragraphId, newIndex);
    note.persist();
    broadcastNote(note);
  }

  private void insertParagraph(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    final int index = (int) Double.parseDouble(fromMessage.get("index").toString());

    final Note note = notebook.getNote(getOpenNoteId(conn));
    note.insertParagraph(index);
    note.persist();
    broadcastNote(note);
  }


  private void cancelParagraph(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    final String paragraphId = (String) fromMessage.get("id");
    if (paragraphId == null) {
      return;
    }

    final Note note = notebook.getNote(getOpenNoteId(conn));
    Paragraph p = note.getParagraph(paragraphId);
    p.abort();
  }

  private void runParagraph(WebSocket conn, Notebook notebook, Message fromMessage)
      throws IOException {
    final String paragraphId = (String) fromMessage.get("id");
    if (paragraphId == null) {
      return;
    }
    final Note note = notebook.getNote(getOpenNoteId(conn));
    Paragraph p = note.getParagraph(paragraphId);
    String text = (String) fromMessage.get("paragraph");
    p.setText(text);
    p.setTitle((String) fromMessage.get("title"));
    Map<String, Object> params = (Map<String, Object>) fromMessage.get("params");
    p.settings.setParams(params);
    Map<String, Object> config = (Map<String, Object>) fromMessage.get("config");
    p.setConfig(config);

    // if it's the last paragraph, let's add a new one
    boolean isTheLastParagraph = note.getLastParagraph().getId().equals(p.getId());
    if (!Strings.isNullOrEmpty(text) && isTheLastParagraph) {
      note.addParagraph();
    }
    note.persist();
    broadcastNote(note);

    note.run(paragraphId);
  }

  /**
   * Need description here.
   *
   */
  public static class ParagraphJobListener implements JobListener {
    private NotebookServer notebookServer;
    private Note note;

    public ParagraphJobListener(NotebookServer notebookServer, Note note) {
      this.notebookServer = notebookServer;
      this.note = note;
    }

    @Override
    public void onProgressUpdate(Job job, int progress) {
      notebookServer.broadcast(note.id(),
          new Message(OP.PROGRESS).put("id", job.getId()).put("progress", job.progress()));
    }

    @Override
    public void beforeStatusChange(Job job, Status before, Status after) {}

    @Override
    public void afterStatusChange(Job job, Status before, Status after) {
      if (after == Status.ERROR) {
        job.getException().printStackTrace();
      }
      if (job.isTerminated()) {
        LOG.info("Job {} is finished", job.getId());
        try {
          note.persist();
        } catch (IOException e) {
          e.printStackTrace();
        }
      }
      notebookServer.broadcastNote(note);
    }
  }

  @Override
  public JobListener getParagraphJobListener(Note note) {
    return new ParagraphJobListener(this, note);
  }
}
