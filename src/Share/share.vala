//	This file is part of FeedReader.
//
//	FeedReader is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	FeedReader is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with FeedReader.  If not, see <http://www.gnu.org/licenses/>.

public class FeedReader.Share : GLib.Object {

	private Gee.ArrayList<ShareAccount> m_accounts;
	private Peas.ExtensionSet m_plugins;

	public Share()
	{
		var engine = Peas.Engine.get_default();
		engine.add_search_path(InstallPrefix + "/share/FeedReader/pluginsShare/", null);
		engine.enable_loader("python3");

		m_plugins = new Peas.ExtensionSet(engine, typeof(ShareAccountInterface), "m_logger", logger);

		m_plugins.extension_added.connect((info, extension) => {
			var plugin = (extension as ShareAccountInterface);
			plugin.addAccount.connect(accountAdded);
			plugin.deleteAccount.connect(deleteAccount);
		});

		m_plugins.extension_removed.connect((info, extension) => {

		});

		foreach(var plugin in engine.get_plugin_list())
		{
			engine.try_load_plugin(plugin);
		}

		refreshAccounts();
	}

	private void refreshAccounts()
	{
		logger.print(LogMessage.DEBUG, "Share: refreshAccounts");
		m_accounts = new Gee.ArrayList<ShareAccount>();
		m_plugins.foreach((@set, info, exten) => {
			var plugin = (exten as ShareAccountInterface);
			if(plugin.needSetup())
			{
				var settings_share = new GLib.Settings("org.gnome.feedreader.share");
				var accounts = settings_share.get_strv(plugin.pluginID());
				foreach(string id in accounts)
				{
					m_accounts.add(
						new ShareAccount(
							id,
							plugin.pluginID(),
							plugin.getUsername(id),
							plugin.getIconName(),
							plugin.pluginName()
						)
					);
				}
			}
			else
			{
				m_accounts.add(
					new ShareAccount(
						"",
						plugin.pluginID(),
						plugin.pluginName(),
						plugin.getIconName(),
						plugin.pluginName()
					)
				);
			}
		});
	}

	private ShareAccountInterface? getInterface(string type)
	{
		ShareAccountInterface? plug = null;

		m_plugins.foreach((@set, info, exten) => {
			var plugin = (exten as ShareAccountInterface);

			if(plugin.pluginID() == type)
			{
				plug = plugin;
			}
		});

		return plug;
	}

	public Gee.ArrayList<ShareAccount> getAccountTypes()
	{
		var accounts = new Gee.ArrayList<ShareAccount>();

		m_plugins.foreach((@set, info, exten) => {
			var plugin = (exten as ShareAccountInterface);

			if(plugin.needSetup())
			{
				accounts.add(new ShareAccount("", plugin.pluginID(), "", plugin.getIconName(), plugin.pluginName()));
			}
		});

		return accounts;
	}


	public Gee.ArrayList<ShareAccount> getAccounts()
	{
		return m_accounts;
	}


	public void deleteAccount(string accountID)
	{
		foreach(var account in m_accounts)
		{
			if(account.getID() == accountID)
			{
				m_accounts.remove(account);
			}
		}
	}

	public static string generateNewID()
	{
		string id = Utils.string_random(12);


		var share_settings = new GLib.Settings("org.gnome.feedreader.share");
		string[] keys = share_settings.list_keys();

		foreach(string key in keys)
		{
			string[] ids = share_settings.get_strv(key);
			foreach(string i in ids)
			{
				if(i == id)
				{
					return generateNewID();
				}
			}
		}

		return id;
	}

	public void accountAdded(string id, string type, string username, string iconName, string accountName)
	{
		logger.print(LogMessage.DEBUG, "Share: %s account added for user: %s".printf(type, username));
		m_accounts.add(new ShareAccount(id, type, username, iconName, accountName));
	}


	public string getUsername(string accountID)
	{
		foreach(var account in m_accounts)
		{
			if(account.getID() == accountID)
			{
				return getInterface(account.getType()).getUsername(accountID);
			}
		}

		return "";
	}


	public bool addBookmark(string accountID, string url)
	{
		foreach(var account in m_accounts)
		{
			if(account.getID() == accountID)
			{
				return getInterface(account.getType()).addBookmark(accountID, url);
			}
		}

		return false;
	}

	public bool needSetup(string accountID)
	{
		foreach(var account in m_accounts)
		{
			if(account.getID() == accountID)
			{
				return getInterface(account.getType()).needSetup();
			}
		}

		return false;
	}

	public ServiceSetup? newSetup_withID(string accountID)
	{
		foreach(var account in m_accounts)
		{
			if(account.getID() == accountID)
			{
				return getInterface(account.getType()).newSetup_withID(account.getID(), account.getUsername());
			}
		}

		return null;
	}

	public ServiceSetup? newSetup(string type)
	{
		return getInterface(type).newSetup();
	}

	public ShareForm? shareWidget(string type, string url)
	{
		ShareForm? form = null;

		m_plugins.foreach((@set, info, exten) => {
			var plugin = (exten as ShareAccountInterface);

			if(plugin.pluginID() == type)
			{
				form = plugin.shareWidget(url);
			}
		});

		return form;
	}
}
