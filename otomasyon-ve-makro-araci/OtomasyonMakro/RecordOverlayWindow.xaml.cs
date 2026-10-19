using System.Windows;

namespace OtomasyonMakro
{
    public partial class RecordOverlayWindow : Window
    {
        public RecordOverlayWindow()
        {
            InitializeComponent();
            Width = SystemParameters.PrimaryScreenWidth;
            Loaded += (_, _) =>
            {
                Left = 0;
                Top = 0;
                Width = SystemParameters.PrimaryScreenWidth;
            };
        }
    }
}
